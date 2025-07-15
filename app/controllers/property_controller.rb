require 'csv'

class PropertyController < ApplicationController
  def csv_insert
    if params[:csv_file].present?
      uploaded_file = params[:csv_file]
      if uploaded_file.content_type == 'text/csv' || File.extname(uploaded_file.original_filename).downcase == '.csv'
        properties = []
        building_type_map = { 'アパート' => 0, '一戸建て' => 1, 'マンション' => 2 }
        required_count = 0
        skipped_count = 0
        CSV.foreach(uploaded_file.path, headers: true, encoding: 'UTF-8') do |row|
          unique_id = row['ユニークID']
          name = row['物件名']
          building_type = row['建物の種類']
          room_number = row['部屋番号']
          # 必須項目チェック
          if unique_id.blank? || name.blank? || (room_number.blank? && building_type != '一戸建て')
            skipped_count += 1
            next
          end
          # 一戸建ての場合は部屋番号をNULL
          room_number = nil if building_type == '一戸建て' && room_number.blank?
          properties << {
            id: unique_id,
            name: name,
            address: row['住所'],
            room_number: room_number,
            rent: row['賃料'],
            area: row['広さ'],
            building_type: building_type_map[building_type]
          }
          required_count += 1
        end
        updated_count = 0
        Csv2db::Property.transaction do
          properties.each_slice(1000) do |batch|
            result = Csv2db::Property.upsert_all(batch, unique_by: :id)
            updated_count += result.length
          end
        end
        flash[:notice] = "登録・更新:#{updated_count}件、エラー:#{skipped_count}件"
      else
        flash[:alert] = 'only CSV files are allowed'
      end
      redirect_to csv_insert_property_index_path
    else
      render :csv_insert
    end
  end
end
