require File.expand_path('../../test_helper', __FILE__)
require 'shell_test/timeout_timer'

class TimeoutTimerTest < Test::Unit::TestCase
  TimeoutTimer = ShellTest::TimeoutTimer

  class Clock
    attr_reader :times

    def initialize(*times)
      @times = times
    end

    def now
      @times.shift
    end
  end

  attr_accessor :timer

  def setup
    super
    @timer = TimeoutTimer.new
  end

  #
  # current_time test
  #

  def test_current_time_returns_now_as_specified_by_clock
    timer = TimeoutTimer.new Clock.new(10, 20, 30)

    assert_equal 10, timer.current_time
    assert_equal 20, timer.current_time
    assert_equal 30, timer.current_time
    assert_equal nil, timer.current_time
  end

  #
  # start test
  #

  def test_start_sets_times_relative_to_current_time
    timer = TimeoutTimer.new Clock.new(10)
    timer.start(100)

    assert_equal 10, timer.start_time
    assert_equal 110, timer.stop_time
    assert_equal 110, timer.mark_time
  end

  #
  # stop test
  #

  def test_stop_returns_time_elapsed_since_start_as_determined_by_current_time
    timer = TimeoutTimer.new Clock.new(0, 8)
    timer.start
    assert_equal 8, timer.stop
  end

  def test_stop_sets_times_to_zero
    timer.start
    timer.stop
    assert_equal 0, timer.start_time
    assert_equal 0, timer.stop_time
    assert_equal 0, timer.mark_time
  end

  #
  # set_timeout test
  #

  def test_set_timeout_sets_mark_time_relative_to_current_time
    timer = TimeoutTimer.new Clock.new(0, 10)
    timer.start

    timer.set_timeout(50)
    assert_equal 60, timer.mark_time
  end

  def test_set_timeout_preserves_current_mark_if_duration_is_negative
    timer = TimeoutTimer.new Clock.new(0, 10, 20)
    timer.start

    timer.set_timeout(50)
    assert_equal 60, timer.mark_time

    timer.set_timeout(-1)
    assert_equal 60, timer.mark_time
  end

  def test_set_timeout_sets_mark_time_to_stop_time_if_duration_is_nil
    timer = TimeoutTimer.new Clock.new(0, 10, 20)
    timer.start(100)

    assert_equal 100, timer.stop_time

    timer.set_timeout(50)
    assert_equal 60, timer.mark_time

    timer.set_timeout(nil)
    assert_equal 100, timer.mark_time
  end

  def test_set_timeout_sets_mark_time_to_stop_time_if_greater_than_stop_time
    timer = TimeoutTimer.new Clock.new(0, 10)
    timer.start(100)

    assert_equal 100, timer.stop_time

    timer.set_timeout(200)
    assert_equal 100, timer.mark_time
  end

  #
  # timeout test
  #

  def test_timeout_returns_duration_from_current_mark_time
    timer = TimeoutTimer.new Clock.new(0, 0, 10, 20, 30)
    timer.start(100)
    timer.set_timeout(50)

    assert_equal 40, timer.timeout
    assert_equal 30, timer.timeout
    assert_equal 20, timer.timeout
  end

  def test_timeout_returns_zero_if_current_time_is_past_mark_time
    timer = TimeoutTimer.new Clock.new(0, 110)
    timer.start(100)

    assert_equal 100, timer.mark_time
    assert_equal(0, timer.timeout)
  end
end