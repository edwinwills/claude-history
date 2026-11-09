class StatsController < ApplicationController
  def show
    @stats = UsageStats.new(period: params[:period])
  end
end
