#!/bin/env ruby -w

require File.dirname(__FILE__) + '/../test_helper'
require 'web'
require 'page'

class PageTest < Test::Unit::TestCase

  class MockWeb < Web
    def initialize() super(nil, 'test','test') end
    def [](wiki_word) %w( MyWay ThatWay SmartEngine ).include?(wiki_word) end
    def refresh_pages_with_references(name) end
  end

  def setup
    @page = Page.new(
      MockWeb.new,
      "FirstPage", 
      "HisWay would be MyWay in kinda ThatWay in HisWay though MyWay \\OverThere -- see SmartEngine in that SmartEngineGUI", 
      Time.local(2004, 4, 4, 16, 50),
      "DavidHeinemeierHansson")
  end

  def test_lock
    assert !@page.locked?(Time.local(2004, 4, 4, 16, 50))

    @page.lock(Time.local(2004, 4, 4, 16, 30), "DavidHeinemeierHansson")

    assert @page.locked?(Time.local(2004, 4, 4, 16, 50))
    assert !@page.locked?(Time.local(2004, 4, 4, 17, 1))

    @page.unlock

    assert !@page.locked?(Time.local(2004, 4, 4, 16, 50))
  end
  
  def test_lock_duration
    @page.lock(Time.local(2004, 4, 4, 16, 30), "DavidHeinemeierHansson")

    assert_equal 15, @page.lock_duration(Time.local(2004, 4, 4, 16, 45))
  end
  
  def test_plain_name
    assert_equal "First Page", @page.plain_name
  end

  def test_revise
    @page.revise('HisWay would be MyWay in kinda lame', Time.local(2004, 4, 4, 16, 55), 'MarianneSyhler')
    assert_equal 2, @page.revisions.length, 'Should have two revisions'
    assert_equal 'MarianneSyhler', @page.author, 'Mary should be the author now'
    assert_equal 'DavidHeinemeierHansson', @page.revisions.first.author, 'David was the first author'
  end
  
  def test_revise_continous_revision
    @page.revise('HisWay would be MyWay in kinda lame', Time.local(2004, 4, 4, 16, 55), 'MarianneSyhler')
    assert_equal 2, @page.revisions.length

    @page.revise('HisWay would be MyWay in kinda update', Time.local(2004, 4, 4, 16, 57), 'MarianneSyhler')
    assert_equal 2, @page.revisions.length
    assert_equal 'HisWay would be MyWay in kinda update', @page.revisions.last.content
    assert_equal Time.local(2004, 4, 4, 16, 57), @page.revisions.last.created_at

    @page.revise('HisWay would be MyWay in the house', Time.local(2004, 4, 4, 16, 58), 'DavidHeinemeierHansson')
    assert_equal 3, @page.revisions.length
    assert_equal 'HisWay would be MyWay in the house', @page.revisions.last.content

    @page.revise('HisWay would be MyWay in my way', Time.local(2004, 4, 4, 17, 30), 'DavidHeinemeierHansson')
    assert_equal 4, @page.revisions.length
  end

  def test_revise_content_unchanged
    last_revision_before = @page.revisions.last
    revisions_number_before = @page.revisions.size
  
    assert_raises(Instiki::ValidationError) { 
      @page.revise(@page.revisions.last.content.dup, Time.now, 'AlexeyVerkhovsky')
    }
    
    assert_same last_revision_before, @page.revisions.last
    assert_equal revisions_number_before, @page.revisions.size
  end

  def test_rollback
    @page.revise("spot two", Time.now, "David")
    @page.revise("spot three", Time.now + 2000, "David")
    assert_equal 3, @page.revisions.length, "Should have three revisions"
    @page.rollback(1, Time.now)
    assert_equal "spot two", @page.content
  end
  
end
