# Service for ActivityPub HTTP Signature verification and signing
# Based on https://www.w3.org/wiki/HttpSignature
module ActivityPub
  class HttpSignature
    # Verify an HTTP signature from a remote server
    # Returns the actor_id if valid, nil otherwise
    def self.verify(request, remote_actor = nil)
      signature_header = request.headers["Signature"]
      return nil if signature_header.blank?

      # Parse signature header
      params = parse_signature_header(signature_header)
      return nil unless params["keyId"] && params["signature"]

      # Get the key ID (actor URL)
      key_id = params["keyId"]

      # If we have a remote actor, verify the key matches
      if remote_actor && remote_actor["publicKey"]
        return nil unless remote_actor["publicKey"]["id"] == key_id ||
                          remote_actor["publicKey"]["id"].end_with?("#main-key")

        public_key = remote_actor["publicKey"]["publicKeyPem"]
      else
        # Fetch the actor to get the public key
        actor = fetch_actor(key_id)
        return nil unless actor && actor["publicKey"]
        public_key = actor["publicKey"]["publicKeyPem"]
      end

      return nil unless public_key

      # Verify the signature
      verify_signature(request, public_key, params["signature"], params["headers"] || "(request-target)")
    end

    # Sign an outgoing request
    def self.sign(request, private_key, key_id, headers: nil)
      headers ||= "(request-target) date host digest content-type"

      # Build the string to sign
      signed_headers = headers.split(" ").map(&:strip)
      signature_parts = signed_headers.map do |header|
        value = case header
                when "(request-target)"
                  " #{request.method.downcase} #{request.path}"
                when "date"
                  " #{request.headers["Date"]}"
                when "host"
                  " #{request.host_with_port}"
                when "digest"
                  " #{request.headers["Digest"]}"
                when "content-type"
                  " #{request.headers["Content-Type"]}"
                else
                  " #{request.headers[header.titleize]}"
                end
        "#{header}#{value}"
      end

      string_to_sign = signature_parts.join("\n")

      # Sign with RSA
      rsa_key = OpenSSL::PKey::RSA.new(private_key)
      signature = Base64.strict_encode64(rsa_key.sign(OpenSSL::Digest::SHA256.new, string_to_sign))

      # Build signature header
      "keyId=\"#{key_id}\",algorithm=\"rsa-sha256\",signature=\"#{signature}\",headers=\"#{headers}\""
    end

    private

    def self.parse_signature_header(header)
      params = {}
      header.split(",").each do |pair|
        key, value = pair.split("=", 2)
        params[key.strip] = value.strip.gsub(/^"|"$/, "")
      end
      params
    end

    def self.verify_signature(request, public_key_pem, signature_b64, headers)
      rsa_key = OpenSSL::PKey::RSA.new(public_key_pem)
      signature = Base64.strict_decode64(signature_b64)

      # Build the string that was signed
      signed_headers = headers.split(" ").map(&:strip)
      signature_parts = signed_headers.map do |header|
        value = case header
                when "(request-target)"
                  " #{request.method.downcase} #{request.path}"
                when "date"
                  " #{request.headers["Date"]}"
                when "host"
                  " #{request.headers["Host"]}"
                when "digest"
                  " #{request.headers["Digest"]}"
                else
                  " #{request.headers[header] || request.headers[header.titleize]}"
                end
        "#{header}#{value}"
      end

      string_to_sign = signature_parts.join("\n")

      rsa_key.verify(OpenSSL::Digest::SHA256.new, signature, string_to_sign)
    end

    def self.fetch_actor(actor_url)
      return nil unless actor_url.start_with?("http")

      uri = URI.parse(actor_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Accept"] = "application/activity+json"

      begin
        response = http.request(request)
        return nil unless response.code == "200"

        JSON.parse(response.body)
      rescue => e
        Rails.logger.error("Failed to fetch actor: #{e.message}")
        nil
      end
    end
  end
end
