#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler'
Bundler.require

require_relative 'media_wiki'

MW = MediaWiki.new(ARGV.shift.chomp('/'))

@nodes = Hash.new do |h, k|
  h[k] = { id: h.length, labelled: false }
end

def node_format(page)
  attrs = { label: page.to_s, style: 'filled', fillcolor: '#ffffffff' }

  attrs[:fillcolor] = '#ffcc00ff' if page.category?

  if page.wanted?
    attrs[:fontcolor] = '#cc0000ff'
  else
    attrs[:URL] = page.url
  end

  attrs[:fontcolor] = '#006600ff' if page.redirect?

  attrs
end

def edge_format(from, to)
  color = case # rubocop:disable Style/EmptyCaseCondition
          when to.wanted? then '#cc0000ff'     # Missing page
          when to.redirect? then '#0066ccff'   # Links to redirects
          when from.redirect? then '#006600ff' # Redirects
          when from.wanted? then '#ff6600ff'   # Missing category
          when to.category? then '#000000ff'   # Subcategory
          when from.category? then '#ffcc00ff' # Page in category
          else '#000000ff'
          end

  { color: color }
end

def gv_format(attrs)
  return '' if attrs.empty?

  fmt = attrs.map { |k, v| "#{k}=#{v.inspect}" }.join(', ')
  "[#{fmt}]"
end

def node(page)
  n = @nodes[page.to_s][:id]
  @nodes[page.to_s][:labelled] = true

  puts "  n#{n} #{gv_format(node_format(page))};"
end

def edge(*pages)
  that, this = pages.map { |p| @nodes[p.to_s][:id] }
  puts "  n#{that} -> n#{this} #{gv_format(edge_format(*pages))};"
end

puts 'digraph mw {'
puts '  ratio=1.42;'
puts '  rankdir="LR";'
puts

MW.all_categories.each do |c|
  warn c

  node c
  c.pages.each { |p| edge(c, p) }
  c.subcategories.each { |s| edge(c, s) }
end

MW.all_pages.each do |p|
  warn p

  node p
  p.links_to.each { |l| edge(l, p) }
end

@nodes.reject { |_, n| n[:labelled] }.each do |title, node|
  warn title

  attrs = { label: title }
  puts "  n#{node[:id]} #{gv_format(attrs)};"
end

puts '}'
