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
        error_messages = []
        CSV.foreach(uploaded_file.path, headers: true, encoding: 'UTF-8') do |row|
          # 建物の種類の検証
          unless building_type_map.key?(row['建物の種類'])
            skipped_count += 1
            error_messages << "行 #{row['ユニークID']} 的建物の種類不合法: #{row['建物の種類']}不在于允许的类型列表"
            next
          end

          unique_id = row['ユニークID']
          name = row['物件名']
          address = row['住所']
          room_number = row['部屋番号']
          rent = row['賃料']
          area = row['広さ']
          building_type = building_type_map[row['建物の種類']]

          temp_property = Csv2db::Property.new(
            id: unique_id,
            name: name,
            address: address,
            room_number: room_number,
            rent: rent,
            area: area,
            building_type: building_type
          )

          puts "Processing property: #{temp_property.attributes.inspect}"

          unless temp_property.valid?
            skipped_count += 1
            error_messages << "行 #{row['ユニークID']} 的数据不合法: #{temp_property.errors.full_messages.join(', ')}"
            next
          end

          properties << {
            id: unique_id,
            name: name,
            address: address,
            room_number: room_number,
            rent: rent,
            area: area,
            building_type: building_type_map[row['建物の種類']]
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

        if error_messages.any?
          displayed_errors = error_messages.first(20)
          flash[:alert_messages] = displayed_errors
          if error_messages.size > 20
            flash[:undisplayed_errors] = "还有 #{error_messages.size - 20} 个错误未显示"
          end
        end
      else
        flash[:alert] = 'only CSV files are allowed'
      end
      redirect_to csv_insert_property_index_path
    else
      render :csv_insert
    end
  end
end
