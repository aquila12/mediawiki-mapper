# frozen_string_literal: true

require 'rest-client'
require 'nokogiri'
require 'memoist'
require 'delegate'
require 'uri'

# Wrapper around mediawiki functionality
class MediaWiki < RestClient::Resource
  extend Memoist

  def initialize(webroot, ...)
    @webroot = webroot.chomp '/'
    super(webroot, ...)
  end

  def qualify_url(href)
    u = URI.parse(@webroot)
    u.path = href
    u.to_s
  end

  # Wrapper for page nodes
  class Page < SimpleDelegator
    def initialize(wiki, ...)
      @wiki = wiki
      super(...)
    end

    def page_title
      self['title'] unless wanted?
      self['title'].chomp(' (page does not exist)')
    end

    def to_s
      page_title || super
    end

    def url
      @wiki.qualify_url self['href']
    end

    def redirect?
      classes.include? 'mw-redirect'
    end

    def wanted?
      classes.include? 'new'
    end

    def category?
      is_a? Category
    end

    def links_to
      @wiki.get_select(
        'Special:WhatLinksHere',
        target: to_s,
        css: '#mw-whatlinkshere-list li > a'
      )
    end
  end

  # Wrapper for category nodes
  class Category < Page
    def subcategories
      @wiki.get_select(
        page_title.tr(' ', '_'),
        css: '#mw-subcategories li > a',
        delegate: self.class
      )
    end

    def pages
      @wiki.get_select(
        page_title.tr(' ', '_'),
        css: '#mw-pages li > a'
      )
    end
  end

  def page(title)
    all_pages.detect { |p| p.to_s == title }
  end

  def all_pages
    get_select(
      'Special:AllPages',
      css: '.mw-allpages-chunk li > a'
    ) + get_select(
      'Special:WantedPages',
      css: '.mw-spcontent li > a.new'
    )
  end

  def all_categories
    get_select(
      'Special:Categories',
      css: '.mw-spcontent li > a',
      delegate: Category
    )
  end

  # private

  # NB: memoist doesn't play properly with kwargs
  def _get(path, params)
    self[path].get(params: params)
  end
  memoize :_get

  def get_select(path, css:, delegate: Page, **params)
    Nokogiri::HTML(_get(path, params)).css(css).map do |p|
      delegate.new(self, p)
    end
  rescue RestClient::NotFound
    []
  end
end
