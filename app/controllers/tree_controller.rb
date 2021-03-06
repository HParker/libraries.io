class TreeController < ApplicationController
  before_action :find_project

  def show
    find_version
    if @version.nil?
      @version = @project.latest_stable_release
      raise ActiveRecord::RecordNotFound if @version.nil?
    end
    @kind = params[:kind] || 'normal'
    @project_names = [@project.name]
    @license_names = @project.normalize_licenses
  end
end
