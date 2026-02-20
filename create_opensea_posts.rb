#!/usr/bin/env ruby
# Script to create sample posts for opensea collection

ENV['RAILS_ENV'] ||= 'development'
require File.expand_path('config/environment', __dir__)

collection = Collection.find_by(alias: 'opensea')
user = collection.owner

# Create some test posts
posts_data = [
  { title: 'Bored Ape #1234', content: 'A rare Bored Ape NFT from the original collection' },
  { title: 'CryptoPunks #5822', content: 'Classic CryptoPunk pixel art collectible' },
  { title: 'Art Blocks #42', content: 'Generative art piece from Art Blocks collection' }
]

puts "Creating sample posts for opensea collection...\n"

posts_data.each do |post_data|
  post = collection.posts.create!(
    owner: user,
    title: post_data[:title],
    content: post_data[:content],
    privacy: 0  # public
  )
  puts "✓ Created: #{post.title} (ID: #{post.id})"
end

puts "\nTotal posts in opensea: #{collection.posts.count}"
