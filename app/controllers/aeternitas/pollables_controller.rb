module Aeternitas
  class PollablesController < Aeternitas::ApplicationController
    before_action :set_pollable, except: [:index]
    before_action :set_time_range, except: [:index, :show]


    def index
      respond_to do |format|
        format.html { }
        format.json { }
      end
    end

    def show ; end

    def timeline
      respond_to do |format|
        format.json { render json: Aeternitas::PollableStatistics.timeline(@pollable, @from, @to)}
      end
    end

    def execution_time
      respond_to do |format|
        format.json { render json: Aeternitas::PollableStatistics.execution_time(@pollable, @from, @to)}
      end
    end

    def pollable_growth
      respond_to do |format|
        format.json { render json: Aeternitas::PollableStatistics.pollable_growth(@pollable, @from, @to)}
      end
    end

    private

    def set_pollable
      pollable_name = params.fetch(:id)

      if Aeternitas::PollableMetaData.where(pollable_class: pollable_name).exists?
        @pollable = pollable_name.constantize
      else
        render_error(404, "Pollable of type #{pollable_name} not found")
        false
      end
    end

    def set_time_range
      @from = DateTime.parse(params.require(:from))
      @to = DateTime.parse(params.require(:to))
    end
  end
end