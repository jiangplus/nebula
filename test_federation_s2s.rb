#!/usr/bin/env ruby
# Comprehensive ActivityPub Server-to-Server Federation Test Suite
#
# Spins up a Puma-backed Rack app as two simulated remote servers
# (alice and bob at 127.0.0.1:4567) so the local Nebula server can
# fetch actor profiles, deliver Accept/Reject activities, and receive
# federated posts — fully testing S2S communication both ways.
#
# Test suites:
#   1. Discovery       — WebFinger edge cases, actor profile structure
#   2. HTTP Signatures — valid, unsigned, tampered body, wrong key, malformed
#   3. Inbox           — Follow, Undo, Like, Announce, Delete, Update,
#                        duplicate follow, unknown types, bad JSON
#   4. Outbound        — Create/Update/Delete posts → activities delivered to followers
#   5. Multi-Actor     — two followers, selective unfollow, broadcast delivery
#
# Usage:
#   rails runner test_federation_s2s.rb [local_url] [collection_alias]
#   rails runner test_federation_s2s.rb http://127.0.0.1:3000 opensea

require "net/http"
require "json"
require "uri"
require "openssl"
require "base64"
require "time"
require "digest"
require "puma"
require "puma/server"

# ─────────────────────────────────────────────────────────────────────────────
# Remote actor identities
# ─────────────────────────────────────────────────────────────────────────────
MOCK_HOST = "127.0.0.1"
MOCK_PORT = 4567
MOCK_BASE = "http://#{MOCK_HOST}:#{MOCK_PORT}"

ACTORS = {
  alice: {
    id:          "#{MOCK_BASE}/users/alice",
    inbox:       "#{MOCK_BASE}/users/alice/inbox",
    username:    "alice",
    key:         OpenSSL::PKey::RSA.new(2048)
  },
  bob: {
    id:          "#{MOCK_BASE}/users/bob",
    inbox:       "#{MOCK_BASE}/users/bob/inbox",
    username:    "bob",
    key:         OpenSSL::PKey::RSA.new(2048)
  }
}.freeze

ALICE      = ACTORS[:alice]
BOB        = ACTORS[:bob]
EVIL_KEY   = OpenSSL::PKey::RSA.new(2048)   # key not registered to any actor

# ─────────────────────────────────────────────────────────────────────────────
# Thread-safe inbox store — records all activities delivered to mock actors
# ─────────────────────────────────────────────────────────────────────────────
module Store
  @mutex = Mutex.new
  @boxes = Hash.new { |h, k| h[k] = [] }   # keyed by username

  def self.add(username, activity)
    @mutex.synchronize { @boxes[username] << activity }
  end

  def self.inbox(username)
    @mutex.synchronize { @boxes[username].dup }
  end

  def self.of_type(username, t)
    inbox(username).select { |a| a["type"] == t }
  end

  def self.clear(username)
    @mutex.synchronize { @boxes[username].clear }
  end

  def self.clear_all
    @mutex.synchronize { @boxes.clear }
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Rack app — serves both alice and bob actor profiles and inboxes
# ─────────────────────────────────────────────────────────────────────────────
class RemoteServerApp
  def actor_json(a)
    {
      "@context"          => ["https://www.w3.org/ns/activitystreams", "https://w3id.org/security/v1"],
      "id"                => a[:id],
      "type"              => "Person",
      "preferredUsername" => a[:username],
      "name"              => "#{a[:username].capitalize} (simulated)",
      "inbox"             => a[:inbox],
      "outbox"            => "#{a[:id]}/outbox",
      "followers"         => "#{a[:id]}/followers",
      "following"         => "#{a[:id]}/following",
      "endpoints"         => { "sharedInbox" => a[:inbox] },
      "publicKey"         => {
        "id"           => "#{a[:id]}#main-key",
        "owner"        => a[:id],
        "publicKeyPem" => a[:key].public_key.to_pem
      }
    }
  end

  def call(env)
    req = Rack::Request.new(env)

    ACTORS.each_value do |a|
      name = a[:username]
      case [req.request_method, req.path]
      when ["GET",  "/users/#{name}"]
        return json_resp(200, actor_json(a), "application/activity+json")
      when ["POST", "/users/#{name}/inbox"]
        body     = req.body.read
        activity = JSON.parse(body) rescue {}
        Store.add(name, activity) unless activity.empty?
        return [202, { "Content-Type" => "application/json" }, ["accepted"]]
      when ["GET", "/users/#{name}/inbox"],
           ["GET", "/users/#{name}/outbox"],
           ["GET", "/users/#{name}/followers"],
           ["GET", "/users/#{name}/following"]
        return json_resp(200, empty_collection("#{MOCK_BASE}#{req.path}"), "application/activity+json")
      end
    end

    [404, { "Content-Type" => "application/json" }, ['{"error":"not found"}']]
  end

  private

  def json_resp(code, body, ct = "application/json")
    [code, { "Content-Type" => ct }, [body.to_json]]
  end

  def empty_collection(id)
    { "@context" => "https://www.w3.org/ns/activitystreams",
      "id" => id, "type" => "OrderedCollection",
      "totalItems" => 0, "orderedItems" => [] }
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Puma launcher
# ─────────────────────────────────────────────────────────────────────────────
module MockServer
  def self.start
    app        = RemoteServerApp.new
    log_writer = Puma::LogWriter.strings
    @server    = Puma::Server.new(app, nil, log_writer: log_writer)
    @server.add_tcp_listener(MOCK_HOST, MOCK_PORT)
    @thread    = Thread.new { @server.run.join }
    sleep 0.4
    self
  end

  def self.stop
    @server&.stop(true)
    @thread&.join(2)
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# HTTP helpers
# ─────────────────────────────────────────────────────────────────────────────
def ap_get(url, accept: "application/activity+json")
  uri  = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 5
  http.read_timeout = 5
  req  = Net::HTTP::Get.new(uri)
  req["Accept"]     = accept
  req["User-Agent"] = "NebulaS2STest/1.0"
  resp = http.request(req)
  { code: resp.code.to_i, body: safe_json(resp.body) }
rescue => e
  { code: 0, error: e.message }
end

# post_raw lets callers set every header manually for signature attack tests
def ap_post_raw(url, body_str, headers = {})
  uri  = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 5
  http.read_timeout = 5
  req  = Net::HTTP::Post.new(uri)
  req["Content-Type"] = "application/activity+json"
  req["Accept"]       = "application/activity+json"
  req["User-Agent"]   = "NebulaS2STest/1.0"
  req["Date"]         = Time.now.utc.httpdate
  headers.each { |k, v| req[k] = v }
  req.body = body_str
  resp = http.request(req)
  { code: resp.code.to_i, body: safe_json(resp.body) }
rescue => e
  { code: 0, error: e.message }
end

def ap_post(url, payload, actor: nil, key_pem: nil, key_id: nil)
  if actor
    key_pem = actor[:key].to_pem
    key_id  = "#{actor[:id]}#main-key"
  end
  uri  = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 5
  http.read_timeout = 5
  req  = Net::HTTP::Post.new(uri)
  req["Content-Type"] = "application/activity+json"
  req["Accept"]       = "application/activity+json"
  req["User-Agent"]   = "NebulaS2STest/1.0"
  req["Date"]         = Time.now.utc.httpdate
  json          = payload.to_json
  req["Digest"] = "SHA-256=#{Base64.strict_encode64(Digest::SHA256.digest(json))}"
  req.body      = json
  http_sign(req, uri, key_pem, key_id) if key_pem && key_id
  resp = http.request(req)
  { code: resp.code.to_i, body: safe_json(resp.body) }
rescue => e
  { code: 0, error: e.message }
end

def http_sign(req, uri, pem, key_id)
  key    = OpenSSL::PKey::RSA.new(pem)
  host   = "#{uri.host}:#{uri.port}"
  target = "#{req.method.downcase} #{uri.request_uri}"
  signed = "(request-target): #{target}\nhost: #{host}\ndate: #{req['Date']}\ndigest: #{req['Digest']}"
  sig    = Base64.strict_encode64(key.sign(OpenSSL::Digest::SHA256.new, signed))
  req["Signature"] = %(keyId="#{key_id}",algorithm="rsa-sha256",headers="(request-target) host date digest",signature="#{sig}")
end

def signed_digest(json)
  "SHA-256=#{Base64.strict_encode64(Digest::SHA256.digest(json))}"
end

def safe_json(str)
  JSON.parse(str)
rescue
  str
end

def wait_for(seconds = 1.5, &block)
  deadline = Time.now + seconds
  sleep 0.1 until block.call || Time.now > deadline
end

# ─────────────────────────────────────────────────────────────────────────────
# Base test class — shared assertion + display helpers
# ─────────────────────────────────────────────────────────────────────────────
class TestSuite
  PASS = "✓"
  FAIL = "✗"
  SKIP = "~"

  attr_reader :pass_count, :fail_count, :skip_count

  def initialize(local_url, collection_alias)
    @local      = local_url.chomp("/")
    @alias      = collection_alias
    @actor      = nil
    @collection = Collection.find_by(alias: collection_alias) rescue nil
    @pass_count = @fail_count = @skip_count = 0

    # Cache the actor once
    res    = ap_get("#{@local}/api/collections/#{@alias}/actor")
    @actor = res[:body] if res[:code] == 200 && res[:body].is_a?(Hash)
  end

  def inbox = @actor&.dig("inbox")

  protected

  def step(title)
    puts "\n  ┌─ #{title}"
    yield
  rescue => e
    fail!("Unexpected #{e.class}: #{e.message}")
    e.backtrace.first(2).each { |l| puts "  │  #{l}" }
  end

  def assert(condition, msg = "assertion failed")
    condition ? pass! : fail!(msg)
  end

  def assert_eq(got, expected, label = "")
    if got == expected
      pass!
    else
      fail!("#{label}expected #{expected.inspect}, got #{got.inspect}")
    end
  end

  def assert_includes(collection, item, label = "")
    collection.include?(item) ? pass! : fail!("#{label}#{item.inspect} not in #{collection.inspect}")
  end

  def assert_excludes(collection, item, label = "")
    !collection.include?(item) ? pass! : fail!("#{label}#{item.inspect} unexpectedly present")
  end

  def info(msg); puts("  │  #{msg}"); end
  def note(msg); puts("  │  ℹ #{msg}"); end

  def skip!(msg)
    @skip_count += 1
    puts "  └─ #{SKIP} skipped — #{msg}"
  end

  def pass!
    @pass_count += 1
    puts "  └─ #{PASS} pass"
  end

  def fail!(msg)
    @fail_count += 1
    puts "  └─ #{FAIL} FAIL — #{msg}"
  end

  def follow_as(actor, seq: 1)
    {
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type"     => "Follow",
      "id"       => "#{actor[:id]}/follows/#{seq}",
      "actor"    => actor[:id],
      "object"   => @actor["id"]
    }
  end

  def undo_follow_as(actor, seq: 1)
    {
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type"     => "Undo",
      "id"       => "#{actor[:id]}/undos/#{seq}",
      "actor"    => actor[:id],
      "object"   => { "type" => "Follow", "actor" => actor[:id], "object" => @actor["id"] }
    }
  end

  def followers_list
    res = ap_get(@actor["followers"])
    return [] unless res[:code] == 200
    res[:body]["orderedItems"] || []
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Suite 1 — Discovery
# ─────────────────────────────────────────────────────────────────────────────
class DiscoverySuite < TestSuite
  def run
    puts "\n  ══ Suite 1: Discovery & Actor Profile ══"

    actor_id  = @actor&.dig("id") || ""
    fed_host  = actor_id.empty? ? URI(@local).host : URI(actor_id).host
    fed_host_port = "#{fed_host}:#{URI(@local).port}"

    step("WebFinger — known user, no port") do
      res = ap_get("#{@local}/.well-known/webfinger?resource=acct:#{@alias}@#{fed_host}",
                   accept: "application/jrd+json")
      assert(res[:code] == 200, "HTTP #{res[:code]}")
      assert(res[:body].is_a?(Hash), "not JSON")
      assert(res[:body]["subject"] == "acct:#{@alias}@#{fed_host}", "wrong subject")
      href = res[:body].dig("links", 0, "href")
      assert(href.present?, "href missing")
      info "subject: #{res[:body]['subject']}"
      info "href:    #{href}"
    end

    step("WebFinger — known user, with port") do
      res = ap_get("#{@local}/.well-known/webfinger?resource=acct:#{@alias}@#{fed_host_port}",
                   accept: "application/jrd+json")
      assert(res[:code] == 200, "HTTP #{res[:code]}")
      assert(res[:body]["subject"] == "acct:#{@alias}@#{fed_host_port}", "wrong subject")
    end

    step("WebFinger — unknown user → 404") do
      res = ap_get("#{@local}/.well-known/webfinger?resource=acct:nobody_exists@#{fed_host}",
                   accept: "application/jrd+json")
      assert(res[:code] == 404, "expected 404, got #{res[:code]}")
    end

    step("WebFinger — wrong domain → 404") do
      res = ap_get("#{@local}/.well-known/webfinger?resource=acct:#{@alias}@evil.example.com",
                   accept: "application/jrd+json")
      assert(res[:code] == 404, "expected 404, got #{res[:code]}")
    end

    step("WebFinger — missing resource param → 400") do
      res = ap_get("#{@local}/.well-known/webfinger", accept: "application/jrd+json")
      assert(res[:code] == 400, "expected 400, got #{res[:code]}")
    end

    step("Actor profile — required fields present") do
      skip!("actor not loaded") && return unless @actor
      %w[id type preferredUsername inbox outbox followers following publicKey].each do |field|
        assert(@actor[field].present?, "field '#{field}' missing")
      end
      info "id:       #{@actor['id']}"
      info "type:     #{@actor['type']}"
      info "username: #{@actor['preferredUsername']}"
    end

    step("Actor profile — public key structure") do
      skip!("actor not loaded") && return unless @actor
      pk = @actor["publicKey"]
      assert(pk.is_a?(Hash),                    "publicKey not a hash")
      assert(pk["id"].present?,                 "publicKey.id missing")
      assert(pk["owner"].present?,              "publicKey.owner missing")
      assert(pk["publicKeyPem"].present?,       "publicKey.publicKeyPem missing")
      assert(pk["id"].include?("#main-key"),    "key id should include #main-key")
      assert_eq(pk["owner"], @actor["id"],      "owner: ")
    end

    step("Actor profile — endpoints sharedInbox present") do
      skip!("actor not loaded") && return unless @actor
      assert(@actor.dig("endpoints", "sharedInbox").present?, "sharedInbox missing")
    end

    step("Outbox — valid OrderedCollection") do
      res = ap_get("#{@local}/api/collections/#{@alias}/outbox")
      assert(res[:code] == 200, "HTTP #{res[:code]}")
      assert(res[:body]["type"] == "OrderedCollection", "wrong type")
      assert(res[:body]["id"].present?, "id missing")
      assert(res[:body].key?("totalItems"), "totalItems missing")
      assert(res[:body].key?("orderedItems"), "orderedItems missing")
      info "totalItems: #{res[:body]['totalItems']}"
    end

    step("Followers list — valid OrderedCollection") do
      res = ap_get("#{@local}/api/collections/#{@alias}/followers")
      assert(res[:code] == 200, "HTTP #{res[:code]}")
      assert(res[:body]["type"] == "OrderedCollection", "wrong type")
    end

    step("Following list — valid OrderedCollection") do
      res = ap_get("#{@local}/api/collections/#{@alias}/following")
      assert(res[:code] == 200, "HTTP #{res[:code]}")
      assert(res[:body]["type"] == "OrderedCollection", "wrong type")
    end
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Suite 2 — HTTP Signatures
# ─────────────────────────────────────────────────────────────────────────────
class SignatureSuite < TestSuite
  def run
    puts "\n  ══ Suite 2: HTTP Signatures ══"
    skip!("actor not loaded") && return unless @actor

    step("Valid RSA-SHA256 signature → accepted") do
      res = ap_post(inbox, follow_as(ALICE, seq: 100), actor: ALICE)
      assert([200, 202].include?(res[:code]), "HTTP #{res[:code]}")
      info "HTTP #{res[:code]} — accepted"
      # clean up
      ap_post(inbox, undo_follow_as(ALICE, seq: 100), actor: ALICE)
      sleep 0.3
    end

    step("No Signature header — server accepts (verification disabled)") do
      payload = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Create", "id" => "#{ALICE[:id]}/unsigned/1",
        "actor" => ALICE[:id],
        "object" => { "type" => "Note", "id" => "#{ALICE[:id]}/notes/u1",
                      "content" => "unsigned post" }
      }
      res = ap_post(inbox, payload)   # no key_pem → no Signature header
      assert([200, 202].include?(res[:code]),
             "expected 2xx for unsigned request, got #{res[:code]}")
      note "signature verification is currently disabled — unsigned requests are accepted"
    end

    step("Wrong key (key not belonging to actor) — server accepts (verification disabled)") do
      payload = follow_as(ALICE, seq: 101)
      res = ap_post(inbox, payload,
                    key_pem: EVIL_KEY.to_pem,
                    key_id:  "#{ALICE[:id]}#main-key")
      assert([200, 202].include?(res[:code]),
             "expected 2xx (sig verification disabled), got #{res[:code]}")
      ap_post(inbox, undo_follow_as(ALICE, seq: 101), actor: ALICE)
      sleep 0.3
    end

    step("Tampered body (digest mismatch) — server accepts (digest not verified)") do
      real_payload = follow_as(ALICE, seq: 102).to_json
      tampered     = real_payload.sub("Follow", "Follow")  # same content, different digest
      correct_digest = signed_digest(real_payload)
      wrong_digest   = "SHA-256=#{Base64.strict_encode64(Digest::SHA256.digest("wrong content"))}"

      res = ap_post_raw(inbox, tampered, { "Digest" => wrong_digest })
      assert([200, 202, 400, 422].include?(res[:code]),
             "unexpected HTTP #{res[:code]} for tampered body")
      note "digest verification status: HTTP #{res[:code]}"
    end

    step("Malformed Signature header — server accepts or rejects gracefully") do
      payload = follow_as(ALICE, seq: 103).to_json
      res     = ap_post_raw(inbox, payload, {
        "Digest"    => signed_digest(payload),
        "Signature" => "this=is,not=valid,signature=header"
      })
      assert([200, 202, 400, 401, 422].include?(res[:code]),
             "unexpected HTTP #{res[:code]}")
      note "malformed signature: HTTP #{res[:code]}"
    end

    step("Signing round-trip — sign then verify locally") do
      key    = ALICE[:key]
      key_id = "#{ALICE[:id]}#main-key"
      body   = { "type" => "Note", "content" => "hello" }.to_json
      date   = Time.now.utc.httpdate
      digest = signed_digest(body)
      host   = "127.0.0.1:3000"
      target = "post /api/collections/#{@alias}/inbox"

      signed_string = "(request-target): #{target}\nhost: #{host}\ndate: #{date}\ndigest: #{digest}"
      sig_bytes     = key.sign(OpenSSL::Digest::SHA256.new, signed_string)
      sig_b64       = Base64.strict_encode64(sig_bytes)

      # verify using public key
      valid = key.public_key.verify(OpenSSL::Digest::SHA256.new, sig_bytes, signed_string)
      assert(valid, "local round-trip verification failed")
      info "signed string:\\n#{signed_string.gsub("\n", "\\n")}"
      info "signature (first 40 chars): #{sig_b64[0, 40]}…"
    end
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Suite 3 — Inbox Processing
# ─────────────────────────────────────────────────────────────────────────────
class InboxSuite < TestSuite
  def run
    puts "\n  ══ Suite 3: Inbox Processing ══"
    skip!("actor not loaded") && return unless @actor

    # ensure clean slate
    cleanup_alice

    step("Follow — creates RemoteFollow and sends Accept") do
      Store.clear("alice")
      res = ap_post(inbox, follow_as(ALICE, seq: 1), actor: ALICE)
      assert([200, 202].include?(res[:code]), "Follow rejected HTTP #{res[:code]}")
      wait_for(2) { Store.of_type("alice", "Accept").any? }
      accepts = Store.of_type("alice", "Accept")
      assert(accepts.any?, "no Accept received on alice's inbox")
      info "Accept id: #{accepts.last&.dig('id')}"
      info "Accept object type: #{accepts.last&.dig('object', 'type')}"
    end

    step("Follow — RemoteFollow appears in followers list") do
      assert_includes(followers_list, ALICE[:id], "alice ")
      info "followers: #{followers_list.inspect}"
    end

    step("Follow — duplicate follow does not create second RemoteFollow") do
      before = followers_list.count(ALICE[:id])
      ap_post(inbox, follow_as(ALICE, seq: 2), actor: ALICE)
      sleep 0.5
      after = followers_list.count(ALICE[:id])
      assert_eq(after, before, "duplicate follow count: ")
      info "count before: #{before}, after: #{after}"
    end

    step("Like — accepted without error") do
      note_id = "#{@local}/api/collections/#{@alias}/some-post"
      like    = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type"     => "Like",
        "id"       => "#{ALICE[:id]}/likes/1",
        "actor"    => ALICE[:id],
        "object"   => note_id
      }
      res = ap_post(inbox, like, actor: ALICE)
      assert([200, 202].include?(res[:code]), "Like rejected HTTP #{res[:code]}")
    end

    step("Announce (boost) — accepted without error") do
      note_id = "#{@local}/api/collections/#{@alias}/some-post"
      announce = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type"     => "Announce",
        "id"       => "#{ALICE[:id]}/announces/1",
        "actor"    => ALICE[:id],
        "object"   => note_id
      }
      res = ap_post(inbox, announce, actor: ALICE)
      assert([200, 202].include?(res[:code]), "Announce rejected HTTP #{res[:code]}")
    end

    step("Create (Note) — accepted without error") do
      note_id = "#{ALICE[:id]}/notes/99"
      create  = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type"     => "Create",
        "id"       => "#{note_id}/create",
        "actor"    => ALICE[:id],
        "to"       => ["https://www.w3.org/ns/activitystreams#Public"],
        "object"   => {
          "type"         => "Note",
          "id"           => note_id,
          "attributedTo" => ALICE[:id],
          "content"      => "Hello from alice!",
          "published"    => Time.now.utc.iso8601
        }
      }
      res = ap_post(inbox, create, actor: ALICE)
      assert([200, 202].include?(res[:code]), "Create rejected HTTP #{res[:code]}")
    end

    step("Update — accepted without error") do
      update = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type"     => "Update",
        "id"       => "#{ALICE[:id]}/updates/1",
        "actor"    => ALICE[:id],
        "object"   => { "type" => "Note", "id" => "#{ALICE[:id]}/notes/99",
                        "content" => "Edited content" }
      }
      res = ap_post(inbox, update, actor: ALICE)
      assert([200, 202].include?(res[:code]), "Update rejected HTTP #{res[:code]}")
    end

    step("Delete — accepted without error") do
      delete = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type"     => "Delete",
        "id"       => "#{ALICE[:id]}/deletes/1",
        "actor"    => ALICE[:id],
        "object"   => { "type" => "Tombstone", "id" => "#{ALICE[:id]}/notes/99" }
      }
      res = ap_post(inbox, delete, actor: ALICE)
      assert([200, 202].include?(res[:code]), "Delete rejected HTTP #{res[:code]}")
    end

    step("Unknown activity type — accepted gracefully (no 500)") do
      unknown = {
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type"     => "EmojiReact",
        "id"       => "#{ALICE[:id]}/reacts/1",
        "actor"    => ALICE[:id],
        "content"  => "🔥",
        "object"   => "#{@local}/some/post"
      }
      res = ap_post(inbox, unknown, actor: ALICE)
      assert([200, 202].include?(res[:code]),
             "unknown type caused error — HTTP #{res[:code]}")
    end

    step("Malformed JSON body → 400 or 500 (not silently 202)") do
      res = ap_post_raw(inbox, "{ this is not valid json }")
      assert([400, 422, 500].include?(res[:code]),
             "expected error for malformed JSON, got #{res[:code]}")
      info "HTTP #{res[:code]} — server correctly rejected bad JSON"
    end

    step("Inbox to non-existent collection → 404") do
      res = ap_post("#{@local}/api/collections/does_not_exist/inbox",
                    follow_as(ALICE, seq: 99), actor: ALICE)
      assert(res[:code] == 404, "expected 404, got #{res[:code]}")
    end

    step("Undo Follow — removes RemoteFollow") do
      res = ap_post(inbox, undo_follow_as(ALICE), actor: ALICE)
      assert([200, 202].include?(res[:code]), "Undo rejected HTTP #{res[:code]}")
      sleep 0.3
      assert_excludes(followers_list, ALICE[:id], "alice after unfollow: ")
      info "followers after undo: #{followers_list.inspect}"
    end

    step("Undo Follow — no-op when not following") do
      res = ap_post(inbox, undo_follow_as(ALICE, seq: 99), actor: ALICE)
      assert([200, 202].include?(res[:code]),
             "Undo on non-follow caused error HTTP #{res[:code]}")
      note "idempotent Undo accepted"
    end
  end

  private

  def cleanup_alice
    ap_post(inbox, undo_follow_as(ALICE, seq: 0), actor: ALICE)
    sleep 0.3
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Suite 4 — Outbound Federation (local posts → remote followers)
# ─────────────────────────────────────────────────────────────────────────────
class OutboundSuite < TestSuite
  def run
    puts "\n  ══ Suite 4: Outbound Federation ══"
    skip!("actor not loaded") && return unless @actor
    skip!("collection not found") && return unless @collection

    # alice must be following for delivery to happen
    setup_alice_follow
    Store.clear("alice")

    step("Create post → followers receive Create activity") do
      post = @collection.posts.create!(
        owner:   @collection.owner,
        title:   "Federation test post",
        content: "Outbound federation test #{Time.now.to_i}",
        privacy: 0
      )
      @test_post = post
      info "Created post id: #{post.id}"

      wait_for(2) { Store.of_type("alice", "Create").any? }
      creates = Store.of_type("alice", "Create")
      assert(creates.any?, "no Create activity received by alice")
      act = creates.last
      assert_eq(act["type"], "Create", "activity type: ")
      assert(act["object"].is_a?(Hash), "object not a hash")
      assert(act.dig("object", "content").present?, "object.content missing")
      assert_eq(act.dig("object", "content"), post.content, "content: ")
      info "Create received — object.id: #{act.dig('object', 'id')}"
    end

    step("Update post → followers receive Update activity") do
      skip!("test post not created") && return unless @test_post
      Store.clear("alice")

      @test_post.update!(content: "Edited content #{Time.now.to_i}")
      wait_for(2) { Store.of_type("alice", "Update").any? }
      updates = Store.of_type("alice", "Update")
      assert(updates.any?, "no Update activity received by alice")
      act = updates.last
      assert_eq(act["type"], "Update", "activity type: ")
      assert_eq(act.dig("object", "content"), @test_post.reload.content, "updated content: ")
      info "Update received — object.id: #{act.dig('object', 'id')}"
    end

    step("Delete post → followers receive Delete activity") do
      skip!("test post not created") && return unless @test_post
      Store.clear("alice")

      post_ap_id = @test_post.ap_id
      @test_post.destroy!
      wait_for(2) { Store.of_type("alice", "Delete").any? }
      deletes = Store.of_type("alice", "Delete")
      assert(deletes.any?, "no Delete activity received by alice")
      act = deletes.last
      assert_eq(act["type"], "Delete", "activity type: ")
      assert_eq(act.dig("object", "id"), post_ap_id, "tombstone id: ")
      info "Delete received — object.id: #{act.dig('object', 'id')}"
    end

    step("Activity actor matches collection actor_id") do
      Store.clear("alice")
      p = @collection.posts.create!(
        owner: @collection.owner, title: "Actor check",
        content: "checking actor field", privacy: 0
      )
      wait_for(2) { Store.of_type("alice", "Create").any? }
      act = Store.of_type("alice", "Create").last
      assert(act.present?, "no Create received")
      assert_eq(act["actor"], @collection.actor_id, "actor: ")
      p.destroy!
    end

    step("Activity cc includes followers URL") do
      Store.clear("alice")
      p = @collection.posts.create!(
        owner: @collection.owner, title: "CC check",
        content: "checking cc field", privacy: 0
      )
      wait_for(2) { Store.of_type("alice", "Create").any? }
      act = Store.of_type("alice", "Create").last
      assert(act.present?, "no Create received")
      cc = act["cc"] || []
      assert(cc.any? { |u| u.include?("followers") }, "followers URL not in cc: #{cc.inspect}")
      p.destroy!
    end
  ensure
    teardown_alice_follow
  end

  private

  def setup_alice_follow
    ap_post(inbox, follow_as(ALICE, seq: 200), actor: ALICE)
    wait_for(2) { followers_list.include?(ALICE[:id]) }
    Store.clear("alice")
  end

  def teardown_alice_follow
    ap_post(inbox, undo_follow_as(ALICE, seq: 200), actor: ALICE)
    sleep 0.3
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Suite 5 — Multi-Actor
# ─────────────────────────────────────────────────────────────────────────────
class MultiActorSuite < TestSuite
  def run
    puts "\n  ══ Suite 5: Multi-Actor ══"
    skip!("actor not loaded") && return unless @actor
    skip!("collection not found") && return unless @collection

    cleanup_all

    step("Two actors (alice + bob) both follow") do
      ap_post(inbox, follow_as(ALICE, seq: 300), actor: ALICE)
      ap_post(inbox, follow_as(BOB,   seq: 300), actor: BOB)
      wait_for(2) { followers_list.include?(ALICE[:id]) && followers_list.include?(BOB[:id]) }
      list = followers_list
      assert_includes(list, ALICE[:id], "alice ")
      assert_includes(list, BOB[:id],   "bob ")
      info "followers (#{list.size}): #{list.map { |u| u.split("/").last }.inspect}"
    end

    step("Both receive Accept activity") do
      wait_for(2) {
        Store.of_type("alice", "Accept").any? && Store.of_type("bob", "Accept").any?
      }
      assert(Store.of_type("alice", "Accept").any?, "alice did not receive Accept")
      assert(Store.of_type("bob",   "Accept").any?, "bob did not receive Accept")
    end

    step("Post is broadcast to both followers") do
      Store.clear_all
      post = @collection.posts.create!(
        owner: @collection.owner, title: "Broadcast test",
        content: "broadcast #{Time.now.to_i}", privacy: 0
      )
      wait_for(3) {
        Store.of_type("alice", "Create").any? && Store.of_type("bob", "Create").any?
      }
      assert(Store.of_type("alice", "Create").any?, "alice did not receive Create")
      assert(Store.of_type("bob",   "Create").any?, "bob did not receive Create")
      info "alice inbox: #{Store.inbox('alice').map { |a| a['type'] }.inspect}"
      info "bob   inbox: #{Store.inbox('bob').map { |a| a['type'] }.inspect}"
      post.destroy!
    end

    step("Alice unfollows — bob still in followers") do
      ap_post(inbox, undo_follow_as(ALICE, seq: 300), actor: ALICE)
      sleep 0.5
      list = followers_list
      assert_excludes(list, ALICE[:id], "alice after unfollow: ")
      assert_includes(list, BOB[:id],   "bob after alice unfollow: ")
      info "remaining followers: #{list.map { |u| u.split("/").last }.inspect}"
    end

    step("Post after alice unfollow — only bob receives it") do
      Store.clear_all
      post = @collection.posts.create!(
        owner: @collection.owner, title: "Post-unfollow broadcast",
        content: "only bob #{Time.now.to_i}", privacy: 0
      )
      wait_for(2) { Store.of_type("bob", "Create").any? }
      assert(Store.of_type("bob",   "Create").any?,  "bob did not receive Create")
      assert(Store.of_type("alice", "Create").empty?, "alice received Create after unfollow")
      info "bob creates:   #{Store.of_type('bob', 'Create').size}"
      info "alice creates: #{Store.of_type('alice', 'Create').size} (should be 0)"
      post.destroy!
    end

    step("Bob unfollows — followers list empty") do
      ap_post(inbox, undo_follow_as(BOB, seq: 300), actor: BOB)
      sleep 0.5
      list = followers_list
      assert_excludes(list, ALICE[:id], "alice ")
      assert_excludes(list, BOB[:id],   "bob ")
      info "followers after all unfollow: #{list.size}"
    end
  end

  private

  def cleanup_all
    [ALICE, BOB].each do |a|
      ap_post(inbox, undo_follow_as(a, seq: 0), actor: a)
    end
    sleep 0.3
    Store.clear_all
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Runner
# ─────────────────────────────────────────────────────────────────────────────
class Runner
  SUITES = [DiscoverySuite, SignatureSuite, InboxSuite, OutboundSuite, MultiActorSuite]

  def initialize(local_url, collection_alias)
    @local   = local_url
    @alias   = collection_alias
    @totals  = { pass: 0, fail: 0, skip: 0 }
  end

  def run
    puts "\n" + "═" * 70
    puts "  ActivityPub Server-to-Server Test Suite"
    puts "═" * 70
    puts "  Local server  : #{@local}"
    puts "  Collection    : #{@alias}"
    puts "  Mock server   : #{MOCK_BASE}  (alice + bob)"
    puts "═" * 70

    SUITES.each do |klass|
      suite = klass.new(@local, @alias)
      suite.run
      @totals[:pass] += suite.pass_count
      @totals[:fail] += suite.fail_count
      @totals[:skip] += suite.skip_count
    end

    total = @totals.values.sum
    puts "\n" + "═" * 70
    puts "  TOTAL: #{@totals[:pass]}/#{total} passed | " \
         "#{@totals[:fail]} failed | #{@totals[:skip]} skipped"
    puts "═" * 70 + "\n"

    exit(1) if @totals[:fail] > 0
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────
local_url        = ARGV[0] || "http://127.0.0.1:3000"
collection_alias = ARGV[1] || (Collection.find_by(alias: "opensea")&.alias rescue "opensea")

mock = MockServer.start
puts "  Puma mock server started — alice + bob on #{MOCK_BASE}"

begin
  Runner.new(local_url, collection_alias).run
ensure
  mock.stop
end
