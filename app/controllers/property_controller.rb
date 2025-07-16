class PropertyController < ApplicationController
  def csv_insert
    if params[:csv_file].present?
      uploaded_file = params[:csv_file]
      if uploaded_file.content_type == 'text/csv' || File.extname(uploaded_file.original_filename).downcase == '.csv'
        # TODO: Add logic here
        flash[:notice] = 'udload successful'
      else
        flash[:alert] = 'only CSV files are allowed'
      end
      redirect_to csv_insert_property_index_path
    else
      render :csv_insert
    end
  end
end
