module Api
  module V1
    class BackgroundChecksController < ApplicationController
      def create
        result = CreateBackgroundCheckService.new(
          candidate_params: candidate_params,
          check_types: params[:check_types] || %w[criminal employment],
          idempotency_key: idempotency_key,
          webhook_url: params[:webhook_url]
        ).call

        if result.success?
          render json: ReportSerializer.new(result.data).as_json,
                 status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def show
        report = Report.find(params[:id])
        render json: ReportSerializer.new(report).as_json
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Report not found" }, status: :not_found
      end

      private

      def candidate_params
        params.require(:candidate).permit(:name, :ssn, :dob, :email)
      end

      def idempotency_key
        request.headers["Idempotency-Key"] || SecureRandom.uuid
      end
    end
  end
end
