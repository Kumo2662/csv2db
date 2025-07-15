require 'csv'

class PropertyController < ApplicationController
  def csv_insert
    if params[:csv_file].present?
      uploaded_file = params[:csv_file]
      if uploaded_file.content_type == 'text/csv' || File.extname(uploaded_file.original_filename).downcase == '.csv'
        properties = []
        building_type_map = { 'アパート' => 0, '一戸建て' => 1, 'マンション' => 2 }
        CSV.foreach(uploaded_file.path, headers: true, encoding: 'UTF-8') do |row|
          properties << {
            id: row['ユニークID'],
            name: row['物件名'],
            address: row['住所'],
            room_number: row['部屋番号'],
            rent: row['賃料'],
            area: row['広さ'],
            building_type: building_type_map[row['建物の種類']]
          }
        end
        updated_count = 0
        Csv2db::Property.transaction do
          properties.each_slice(1000) do |batch|
            result = Csv2db::Property.upsert_all(batch, unique_by: :id)
            updated_count += result.length
          end
        end
        flash[:notice] = "登録・更新:#{updated_count}件"
      else
        flash[:alert] = 'only CSV files are allowed'
      end
      redirect_to csv_insert_property_index_path
    else
      render :csv_insert
    end
  end
end
