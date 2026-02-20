#!/usr/bin/env ruby
# ActivityPub Federation Testing Script
# Tests WebFinger discovery, actor profiles, outbox, followers/following

require 'net/http'
require 'json'
require 'uri'

begin
  require 'colorize'
rescue LoadError
  # colorize not available, script will work without it
end

class FederationTester
  attr_reader :base_url, :collection_alias, :results

  def initialize(base_url = "http://localhost:3000", collection_alias = nil)
    @base_url = base_url
    @collection_alias = collection_alias || find_first_collection
    @results = []
  end

  def run_all_tests
    puts "\n" + "="*70
    puts "ActivityPub Federation Testing"
    puts "="*70
    puts "Base URL: #{@base_url}"
    puts "Collection: #{@collection_alias || 'None found'}"
    puts "="*70 + "\n"

    return if @collection_alias.nil?

    test_webfinger
    test_actor_profile
    test_outbox
    test_followers
    test_following
    test_inbox_follow_activity

    print_summary
  end

  private

  def find_first_collection
    # Default to opensea collection if it exists
    Collection.find_by(alias: 'opensea')&.alias || Collection.first&.alias
  rescue
    nil
  end

  def test_webfinger
    puts "\n[1/6] Testing WebFinger Discovery..."

    # Test with port
    response = http_get(
      "/.well-known/webfinger",
      { resource: "acct:#{@collection_alias}@localhost:3000" },
      "application/jrd+json"
    )

    if response && response['subject']
      log_pass("WebFinger (with port)", "Subject: #{response['subject']}")
    else
      log_fail("WebFinger (with port)")
    end

    # Test without port
    response = http_get(
      "/.well-known/webfinger",
      { resource: "acct:#{@collection_alias}@localhost" },
      "application/jrd+json"
    )

    if response && response['subject']
      log_pass("WebFinger (without port)", "Subject: #{response['subject']}")
    else
      log_fail("WebFinger (without port)")
    end
  end

  def test_actor_profile
    puts "\n[2/6] Testing Actor Profile Endpoint..."

    response = http_get(
      "/api/collections/#{@collection_alias}/actor",
      {},
      "application/activity+json"
    )

    if response && response['id'] && response['type'] == 'Person'
      actor_url = response['id']
      inbox = response['inbox']
      outbox = response['outbox']
      followers = response['followers']
      following = response['following']

      log_pass("Actor Profile", "ID: #{actor_url}")
      log_pass("  ├─ Inbox", inbox)
      log_pass("  ├─ Outbox", outbox)
      log_pass("  ├─ Followers", followers)
      log_pass("  └─ Following", following)

      # Verify public key
      if response['publicKey'] && response['publicKey']['publicKeyPem']
        log_pass("  └─ Public Key", "Present")
      else
        log_fail("  └─ Public Key", "Missing")
      end
    else
      log_fail("Actor Profile")
    end
  end

  def test_outbox
    puts "\n[3/6] Testing Outbox Endpoint..."

    response = http_get(
      "/api/collections/#{@collection_alias}/outbox",
      {},
      "application/activity+json"
    )

    if response && response['type'] == 'OrderedCollection'
      log_pass("Outbox Collection", "ID: #{response['id']}")
      log_pass("  ├─ Total Items", response['totalItems'])

      if response['orderedItems']&.any?
        first_item = response['orderedItems'].first
        log_pass("  └─ Sample Activity", "Type: #{first_item['type']}, ID: #{first_item['id']}")
      end
    else
      log_fail("Outbox Collection")
    end
  end

  def test_followers
    puts "\n[4/6] Testing Followers Endpoint..."

    response = http_get(
      "/api/collections/#{@collection_alias}/followers",
      {},
      "application/activity+json"
    )

    if response && response['type'] == 'OrderedCollection'
      log_pass("Followers Collection", "Total: #{response['totalItems']}")
    else
      log_fail("Followers Collection")
    end
  end

  def test_following
    puts "\n[5/6] Testing Following Endpoint..."

    response = http_get(
      "/api/collections/#{@collection_alias}/following",
      {},
      "application/activity+json"
    )

    if response && response['type'] == 'OrderedCollection'
      log_pass("Following Collection", "Total: #{response['totalItems']}")
    else
      log_fail("Following Collection")
    end
  end

  def test_inbox_follow_activity
    puts "\n[6/6] Testing Inbox (Follow Activity)..."

    actor_url = "#{@base_url}/api/collections/#{@collection_alias}"

    follow_activity = {
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Follow",
      "id" => "http://example.com/follow/#{Time.now.to_i}",
      "actor" => "http://example.com/users/testuser",
      "object" => actor_url
    }

    response = http_post(
      "/api/collections/#{@collection_alias}/inbox",
      follow_activity.to_json,
      "application/activity+json"
    )

    if response && response.is_a?(Net::HTTPSuccess)
      log_pass("Inbox (Follow Activity)", "Accepted (HTTP #{response.code})")

      # Check if RemoteUser was created
      if defined?(RemoteUser)
        remote_user = RemoteUser.find_by(actor_id: "http://example.com/users/testuser")
        if remote_user
          log_pass("  └─ RemoteUser Created", "ID: #{remote_user.id}")
        end
      end
    else
      log_fail("Inbox (Follow Activity)", "HTTP #{response&.code}")
    end
  end

  def http_get(path, params = {}, accept_type = "application/activity+json")
    uri = URI("#{@base_url}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = false
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Get.new(uri)
    request['Accept'] = accept_type
    request['User-Agent'] = 'FederationTester/1.0'

    begin
      response = http.request(request)
      JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
    rescue => e
      puts "Error: #{e.message}"
      nil
    end
  end

  def http_post(path, body, content_type = "application/activity+json")
    uri = URI("#{@base_url}#{path}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = false
    http.open_timeout = 5
    http.read_timeout = 5

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = content_type
    request['Accept'] = content_type
    request['User-Agent'] = 'FederationTester/1.0'
    request.body = body

    begin
      http.request(request)
    rescue => e
      puts "Error: #{e.message}"
      nil
    end
  end

  def log_pass(test_name, details = nil)
    message = "✓ #{test_name}"
    message += " — #{details}" if details
    @results << { test: test_name, status: :pass }
    puts colorize(message, :green)
  end

  def log_fail(test_name, details = nil)
    message = "✗ #{test_name}"
    message += " — #{details}" if details
    @results << { test: test_name, status: :fail }
    puts colorize(message, :red)
  end

  def colorize(text, color)
    return text unless defined?(String::COLORS)

    case color
    when :green then text.green
    when :red then text.red
    when :yellow then text.yellow
    else text
    end
  rescue
    text
  end

  def print_summary
    puts "\n" + "="*70
    passed = @results.count { |r| r[:status] == :pass }
    failed = @results.count { |r| r[:status] == :fail }
    total = @results.length

    puts "Summary: #{passed}/#{total} tests passed"

    if failed > 0
      puts "\nFailed tests:"
      @results.select { |r| r[:status] == :fail }.each do |result|
        puts "  - #{result[:test]}"
      end
    end

    puts "="*70 + "\n"
  end
end

# Main execution
if $0 == __FILE__
  # Load Rails environment if available
  begin
    ENV['RAILS_ENV'] ||= 'development'
    require File.expand_path('config/environment', __dir__)
  rescue LoadError
    # Script can run without Rails
  end

  # Usage: ruby test_federation.rb [base_url] [collection_alias]
  # Examples:
  #   ruby test_federation.rb                          # Uses default (opensea)
  #   ruby test_federation.rb http://localhost:3000 opensea
  #   ruby test_federation.rb http://example.com blog

  base_url = ARGV[0] || "http://localhost:3000"
  collection_alias = ARGV[1]

  tester = FederationTester.new(base_url, collection_alias)
  tester.run_all_tests
end
