require "csv"

class PropertyController < ApplicationController
  SLICE_SIZE = 1000
  SHOW_ERRORS_LIMIT = 20

  BUILDING_TYPE_MAP = Csv2db::Property.building_types.map do |key, value|
    [ I18n.t("enums.csv2db/property.building_type.#{key}"), value ]
  end.to_h

  def csv_insert
    unless params[:csv_file].present?
      render :csv_insert
      return
    end

    uploaded_file = params[:csv_file]
    # Check if the uploaded file is a CSV file
    unless uploaded_file.content_type == "text/csv" || File.extname(uploaded_file.original_filename).downcase == ".csv"
      flash[:alert] = "CSVファイルをアップロードしてください。"
      redirect_to csv_insert_property_index_path
      return
    end

    properties_data = []
    error_messages = []
    skipped_count = 0

    CSV.foreach(uploaded_file.path, headers: true, encoding: "UTF-8") do |row|
      # Validations for csv data
      unless BUILDING_TYPE_MAP.key?(row["建物の種類"])
        skipped_count += 1
        error_messages << "ユニークID #{row['ユニークID']} の物件データが不正です: 「#{row['建物の種類']}」は許可された建物の種類（#{BUILDING_TYPE_MAP.keys.join('、')}）ではありません"
        next
      end

      row_data = {
        id: row["ユニークID"],
        name: row["物件名"],
        address: row["住所"],
        room_number: row["部屋番号"],
        rent: row["賃料"],
        area: row["広さ"],
        building_type: BUILDING_TYPE_MAP[row["建物の種類"]]
      }

      temp_property = Csv2db::Property.new(row_data)
      unless temp_property.valid?
        skipped_count += 1
        error_messages << "ユニークID #{row['ユニークID']} の物件データが不正です: #{temp_property.errors.full_messages.join(', ')}"
        next
      end

      properties_data << row_data
    end

    updated_count = 0
    Csv2db::Property.transaction do
      properties_data.each_slice(SLICE_SIZE) do |batch|
        result = Csv2db::Property.upsert_all(batch, unique_by: :id)
        updated_count += result.length
      end
    end
    flash[:notice] = "登録・更新:#{updated_count}件、エラー:#{skipped_count}件"

    if error_messages.any?
      # Limit the number of displayed error messages
      flash[:alert_messages] = error_messages.first(SHOW_ERRORS_LIMIT)
      if error_messages.size > SHOW_ERRORS_LIMIT
        flash[:undisplayed_errors] = "他に #{error_messages.size - SHOW_ERRORS_LIMIT} 件のエラーがあります...CSVファイルを確認してください。"
      end
    end

    redirect_to csv_insert_property_index_path
  rescue StandardError => e
    Rails.logger.error "CSV Insert Error: #{e.message}"
    flash[:alert] = "#{self.class.name}##{__method__}処理中にエラーが発生しました: #{e.message}"
    if Rails.env.development?
      flash[:alert] += "\n#{e.backtrace.join("\n")}"
    end
    redirect_to csv_insert_property_index_path
  end
end
