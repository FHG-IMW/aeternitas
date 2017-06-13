module Aeternitas
  class DashboardController < Aeternitas::ApplicationController
    def index

    end

    def polls_24h
      @polls = Aeternitas::DashboardStatistics.polls_24h
      respond_to do |format|
        format.json { render json: @polls }
      end
    end

    def future_polls
      @polls = Aeternitas::DashboardStatistics.future_polls

      respond_to do |format|
        format.json { render json: @polls }
      end
    end

    def pollable_growth
      @polls = Aeternitas::DashboardStatistics.pollable_growth
      respond_to do |format|
        format.json { render json: @polls }
      end
    end
  end
end
