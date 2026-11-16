#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'openssl'
require 'net/http'
require 'json'
require 'base64'
require 'uri'

def encrypt_block(key, block)
  cipher = OpenSSL::Cipher.new('AES-128-ECB')
  cipher.encrypt
  cipher.padding = 0
  cipher.key = key
  cipher.update(block) + cipher.final
end

def double_block(block)
  n = block.unpack1('H*').to_i(16)
  carry = (n >> 127) & 1
  n = ((n << 1) & ((1 << 128) - 1)) ^ (carry == 1 ? 0x87 : 0)
  [format('%032x', n)].pack('H*')
end

# CMAC for the three-byte timestamp message used by the supplied API example.
def signature(key, message)
  k1 = double_block(encrypt_block(key, "\0".b * 16))
  k2 = double_block(k1)
  padded = message + "\x80".b + ("\0".b * (15 - message.bytesize))
  block = padded.bytes.zip(k2.bytes).map { |a, b| a ^ b }.pack('C*')
  encrypt_block(key, block).unpack1('H*')
end

begin
  config_path = File.join(__dir__, 'config.yml')
  config = YAML.safe_load(File.read(config_path), permitted_classes: [], aliases: false)
  raise ArgumentError, 'config.yml must contain a mapping' unless config.is_a?(Hash)
  uuid = config.fetch('device_uuid').to_s
  api_key = config.fetch('api_key').to_s
  secret_hex = config.fetch('device_secret_key').to_s
  raise ArgumentError, 'device_uuid is invalid' unless uuid.match?(/\A[0-9a-fA-F-]{36}\z/)
  raise ArgumentError, 'device_secret_key must be 32 hex characters' unless secret_hex.match?(/\A[0-9a-fA-F]{32}\z/)
  raise ArgumentError, 'api_key is empty' if api_key.empty?
  message = [Time.now.to_i].pack('V').byteslice(1, 3)
  payload = { cmd: 82, history: Base64.strict_encode64('cron lock'), sign: signature([secret_hex].pack('H*'), message) }
  uri = URI("https://app.candyhouse.co/api/sesame2/#{uuid}/cmd")
  request = Net::HTTP::Post.new(uri)
  request['x-api-key'] = api_key
  request['Content-Type'] = 'application/json'
  request.body = JSON.generate(payload)
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 15) { |http| http.request(request) }
  if response.is_a?(Net::HTTPSuccess)
    puts "Lock request accepted (HTTP #{response.code}); physical lock state not verified."
  else
    warn "Lock request failed (HTTP #{response.code})."
    exit 1
  end
rescue StandardError => e
  warn "Lock request failed: #{e.class}"
  exit 1
end
