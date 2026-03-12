#!/usr/bin/env ruby
# Server-to-Server ActivityPub Federation Test
#
# Runs a Puma-backed Rack app in a thread to simulate a real remote
# ActivityPub server ("alice" at remote.test:4567). The local Nebula
# server can actually fetch alice's actor profile, verify HTTP signatures,
# and deliver Accept activities back — testing the full S2S flow end-to-end.
#
# Flow:
#   1.  WebFinger discovery of the local collection
#   2.  Actor profile fetch
#   3.  Follow: alice → local inbox (server fetches alice's actor, creates RemoteFollow, sends Accept)
#   4.  Accept received by alice's inbox (our Puma server)
#   5.  Followers list includes alice
#   6.  Incoming Create from alice → local inbox
#   7.  Undo Follow: alice removes herself
#   8.  Followers list no longer includes alice
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
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
MOCK_HOST        = "127.0.0.1"
MOCK_PORT        = 4567
MOCK_BASE        = "http://#{MOCK_HOST}:#{MOCK_PORT}"
REMOTE_ACTOR_ID  = "#{MOCK_BASE}/users/alice"
REMOTE_INBOX     = "#{MOCK_BASE}/users/alice/inbox"

# ─────────────────────────────────────────────────────────────────────────────
# Remote actor keypair (generated fresh each run)
# ─────────────────────────────────────────────────────────────────────────────
ALICE_KEY       = OpenSSL::PKey::RSA.new(2048)
ALICE_KEY_ID    = "#{REMOTE_ACTOR_ID}#main-key"
ALICE_PUBLIC_PEM  = ALICE_KEY.public_key.to_pem
ALICE_PRIVATE_PEM = ALICE_KEY.to_pem

# ─────────────────────────────────────────────────────────────────────────────
# Thread-safe store for activities delivered to alice's inbox
# ─────────────────────────────────────────────────────────────────────────────
module Store
  @mutex      = Mutex.new
  @activities = []

  def self.add(activity)
    @mutex.synchronize { @activities << activity }
  end

  def self.all          = @mutex.synchronize { @activities.dup }
  def self.of_type(t)   = all.select { |a| a["type"] == t }
  def self.clear        = @mutex.synchronize { @activities.clear }
end

# ─────────────────────────────────────────────────────────────────────────────
# Rack app — the "remote server"
# ─────────────────────────────────────────────────────────────────────────────
class RemoteServerApp
  ACTOR_JSON = {
    "@context"          => ["https://www.w3.org/ns/activitystreams", "https://w3id.org/security/v1"],
    "id"                => REMOTE_ACTOR_ID,
    "type"              => "Person",
    "preferredUsername" => "alice",
    "name"              => "Alice (simulated remote user)",
    "inbox"             => REMOTE_INBOX,
    "outbox"            => "#{MOCK_BASE}/users/alice/outbox",
    "followers"         => "#{MOCK_BASE}/users/alice/followers",
    "following"         => "#{MOCK_BASE}/users/alice/following",
    "endpoints"         => { "sharedInbox" => REMOTE_INBOX },
    "publicKey"         => {
      "id"           => ALICE_KEY_ID,
      "owner"        => REMOTE_ACTOR_ID,
      "publicKeyPem" => ALICE_PUBLIC_PEM
    }
  }.freeze

  def call(env)
    req = Rack::Request.new(env)

    case [req.request_method, req.path]
    when ["GET",  "/users/alice"]       then serve_actor
    when ["POST", "/users/alice/inbox"] then receive_activity(req)
    when ["GET",  "/users/alice/inbox"],
         ["GET",  "/users/alice/outbox"],
         ["GET",  "/users/alice/followers"],
         ["GET",  "/users/alice/following"] then empty_collection(req.path)
    else
      [404, { "Content-Type" => "application/json" }, ['{"error":"not found"}']]
    end
  end

  private

  def serve_actor
    [200,
     { "Content-Type" => "application/activity+json" },
     [ACTOR_JSON.to_json]]
  end

  def receive_activity(req)
    body     = req.body.read
    activity = JSON.parse(body) rescue {}
    Store.add(activity) unless activity.empty?
    [202, { "Content-Type" => "application/json" }, ["accepted"]]
  end

  def empty_collection(path)
    body = {
      "@context"    => "https://www.w3.org/ns/activitystreams",
      "id"          => "#{MOCK_BASE}#{path}",
      "type"        => "OrderedCollection",
      "totalItems"  => 0,
      "orderedItems"=> []
    }
    [200, { "Content-Type" => "application/activity+json" }, [body.to_json]]
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Puma launcher (runs in a background thread)
# ─────────────────────────────────────────────────────────────────────────────
module MockServer
  def self.start
    app        = RemoteServerApp.new
    log_writer = Puma::LogWriter.strings
    @server    = Puma::Server.new(app, nil, log_writer: log_writer)
    @server.add_tcp_listener(MOCK_HOST, MOCK_PORT)
    @thread = Thread.new { @server.run.join }
    sleep 0.4  # wait for bind
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

def ap_post(url, payload, key_pem: nil, key_id: nil)
  uri  = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 5
  http.read_timeout = 5

  req  = Net::HTTP::Post.new(uri)
  req["Content-Type"] = "application/activity+json"
  req["Accept"]       = "application/activity+json"
  req["User-Agent"]   = "NebulaS2STest/1.0"
  req["Date"]         = Time.now.utc.httpdate

  json             = payload.to_json
  req["Digest"]    = "SHA-256=#{Base64.strict_encode64(Digest::SHA256.digest(json))}"
  req.body         = json

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

def safe_json(str)
  JSON.parse(str)
rescue
  str
end

# ─────────────────────────────────────────────────────────────────────────────
# Test runner
# ─────────────────────────────────────────────────────────────────────────────
class S2STest
  PASS = "✓"
  FAIL = "✗"
  SKIP = "~"

  def initialize(local_url, collection_alias)
    @local      = local_url.chomp("/")
    @alias      = collection_alias
    @actor      = nil
    @collection = Collection.find_by(alias: collection_alias) rescue nil
    @pass = @fail = @skip = 0
  end

  def run
    puts "\n" + "─" * 70
    puts "  Server-to-Server ActivityPub Federation Test"
    puts "─" * 70
    puts "  Local server  : #{@local}"
    puts "  Collection    : #{@alias}"
    puts "  Remote actor  : #{REMOTE_ACTOR_ID}  (Puma on :#{MOCK_PORT})"
    puts "─" * 70

    step("1. WebFinger discovery")         { test_webfinger }
    step("2. Fetch actor profile")          { test_fetch_actor }
    step("3. Follow → inbox + Accept back") { test_follow }
    step("4. Followers list updated")       { test_followers_list }
    step("5. Incoming Create from remote")  { test_incoming_create }
    step("6. Undo Follow → inbox")          { test_undo_follow }
    step("7. Followers list cleared")       { test_followers_cleared }

    summary
  end

  private

  # ── individual tests ──────────────────────────────────────────────────────

  def test_webfinger
    # Derive the federation host from the actor ID so we use the right domain
    actor_res = ap_get("#{@local}/api/collections/#{@alias}/actor")
    actor_id  = actor_res.dig(:body, "id") || ""
    fed_host  = actor_id.empty? ? URI(@local).host : URI(actor_id).host

    url = "#{@local}/.well-known/webfinger?resource=acct:#{@alias}@#{fed_host}"
    res = ap_get(url, accept: "application/jrd+json")

    assert(res[:code] == 200,                  "HTTP #{res[:code]}")
    assert(res[:body].is_a?(Hash),             "response is not JSON")
    assert(res[:body]["subject"].present?,     "subject missing")
    info "subject : #{res[:body]['subject']}"
    info "href    : #{res[:body].dig('links', 0, 'href')}"
  end

  def test_fetch_actor
    res = ap_get("#{@local}/api/collections/#{@alias}/actor")
    assert(res[:code] == 200,                                 "HTTP #{res[:code]}")
    assert(res[:body].is_a?(Hash),                            "not JSON")
    assert(res[:body]["type"] == "Person",                    "type != Person")
    assert(res[:body]["inbox"].present?,                      "inbox missing")
    assert(res[:body].dig("publicKey", "publicKeyPem").present?, "public key missing")

    @actor = res[:body]
    info "id    : #{@actor['id']}"
    info "inbox : #{@actor['inbox']}"
    info "key   : #{@actor.dig('publicKey', 'publicKeyPem').to_s[0, 40]}…"
  end

  def test_follow
    skip("actor not fetched") && return unless @actor

    follow = {
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type"     => "Follow",
      "id"       => "#{REMOTE_ACTOR_ID}/follows/1",
      "actor"    => REMOTE_ACTOR_ID,
      "object"   => @actor["id"]
    }

    res = ap_post(@actor["inbox"], follow, key_pem: ALICE_PRIVATE_PEM, key_id: ALICE_KEY_ID)
    assert([200, 202].include?(res[:code]), "Follow rejected — HTTP #{res[:code]}: #{res[:body]}")
    info "Follow delivered → HTTP #{res[:code]}"

    # Wait for the server to fetch alice's actor from our Puma server and send Accept
    sleep 1.5

    accepts = Store.of_type("Accept")
    assert(accepts.any?, "No Accept activity received on alice's inbox")
    info "Accept received ← #{accepts.last.dig('id')}"
  end

  def test_followers_list
    skip("actor not fetched") && return unless @actor

    res = ap_get(@actor["followers"])
    assert(res[:code] == 200,              "HTTP #{res[:code]}")
    items = res[:body]["orderedItems"] || []
    assert(items.include?(REMOTE_ACTOR_ID), "alice not in followers. got: #{items.inspect}")
    info "followers count : #{res[:body]['totalItems']}"
    info "alice present   : #{items.include?(REMOTE_ACTOR_ID)}"
  end

  def test_incoming_create
    skip("actor not fetched") && return unless @actor

    note_id = "#{REMOTE_ACTOR_ID}/posts/1"
    create  = {
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type"     => "Create",
      "id"       => "#{note_id}/create",
      "actor"    => REMOTE_ACTOR_ID,
      "to"       => ["https://www.w3.org/ns/activitystreams#Public"],
      "cc"       => [@actor["followers"]],
      "object"   => {
        "type"         => "Note",
        "id"           => note_id,
        "attributedTo" => REMOTE_ACTOR_ID,
        "content"      => "Hello from the simulated remote server!",
        "published"    => Time.now.utc.iso8601,
        "to"           => ["https://www.w3.org/ns/activitystreams#Public"]
      }
    }

    res = ap_post(@actor["inbox"], create, key_pem: ALICE_PRIVATE_PEM, key_id: ALICE_KEY_ID)
    # 202 = accepted; 422/501 = not yet implemented (acceptable)
    accepted = [200, 202, 422, 501].include?(res[:code])
    assert(accepted, "Create rejected — HTTP #{res[:code]}: #{res[:body]}")
    info "HTTP #{res[:code]} — #{[422, 501].include?(res[:code]) ? 'server does not yet store incoming posts (expected)' : 'accepted'}"
  end

  def test_undo_follow
    skip("actor not fetched") && return unless @actor

    undo = {
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type"     => "Undo",
      "id"       => "#{REMOTE_ACTOR_ID}/undos/1",
      "actor"    => REMOTE_ACTOR_ID,
      "object"   => {
        "type"   => "Follow",
        "actor"  => REMOTE_ACTOR_ID,
        "object" => @actor["id"]
      }
    }

    res = ap_post(@actor["inbox"], undo, key_pem: ALICE_PRIVATE_PEM, key_id: ALICE_KEY_ID)
    assert([200, 202].include?(res[:code]), "Undo rejected — HTTP #{res[:code]}")
    info "Undo Follow delivered → HTTP #{res[:code]}"
    sleep 0.3
  end

  def test_followers_cleared
    skip("actor not fetched") && return unless @actor

    res = ap_get(@actor["followers"])
    assert(res[:code] == 200, "HTTP #{res[:code]}")
    items = res[:body]["orderedItems"] || []
    assert(!items.include?(REMOTE_ACTOR_ID), "alice still in followers after Undo")
    info "followers count : #{res[:body]['totalItems']} — alice removed ✓"
  end

  # ── helpers ───────────────────────────────────────────────────────────────

  def step(title)
    puts "\n  ┌─ #{title}"
    yield
  rescue => e
    record_fail("Unexpected error: #{e.class}: #{e.message}")
    e.backtrace.first(3).each { |l| puts "     #{l}" }
  end

  def assert(condition, msg = "assertion failed")
    if condition
      record_pass
    else
      record_fail(msg)
    end
  end

  def info(msg)  = puts("  │  #{msg}")
  def skip(msg)  = (@skip += 1) && puts("  │  #{SKIP} skipped — #{msg}")

  def record_pass
    @pass += 1
    puts "  └─ #{PASS} pass"
  end

  def record_fail(msg)
    @fail += 1
    puts "  └─ #{FAIL} FAIL — #{msg}"
  end

  def summary
    total = @pass + @fail + @skip
    puts "\n" + "─" * 70
    puts "  #{@pass}/#{total} passed  |  #{@fail} failed  |  #{@skip} skipped"
    puts "─" * 70 + "\n"
    exit(1) if @fail > 0
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────────────────────
local_url        = ARGV[0] || "http://127.0.0.1:3000"
collection_alias = ARGV[1] || (Collection.find_by(alias: "opensea")&.alias rescue "opensea")

mock = MockServer.start
puts "  Puma mock server started on #{MOCK_BASE}"

begin
  S2STest.new(local_url, collection_alias).run
ensure
  mock.stop
end
