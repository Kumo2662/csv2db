require 'rails_helper'

RSpec.describe PropertyController, type: :controller do
  describe 'GET #csv_insert' do
    it 'renders the csv_insert template' do
      get :csv_insert
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #csv_insert' do
    let(:valid_csv_file) do
      fixture_file_upload(Rails.root.join('spec/fixtures/files/valid_properties.csv'), 'text/csv')
    end

    let(:invalid_csv_file) do
      fixture_file_upload(Rails.root.join('spec/fixtures/files/invalid_properties.csv'), 'text/csv')
    end

    context 'when no file is uploaded' do
      it 'renders the csv_insert template' do
        post :csv_insert
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when a non-CSV file is uploaded' do
      it 'redirects with an error message' do
        # Create a file with wrong extension
        wrong_file = fixture_file_upload(Rails.root.join('spec/fixtures/files/invalid_properties.csv'), 'text/plain')
        wrong_file.instance_variable_set(:@original_filename, 'test.txt')

        post :csv_insert, params: { csv_file: wrong_file }
        expect(response).to redirect_to(csv_insert_property_index_path)
        expect(flash[:alert]).to eq('CSVファイルをアップロードしてください。')
      end
    end

    context 'when a valid CSV file is uploaded' do
      it 'successfully imports properties' do
        expect {
          post :csv_insert, params: { csv_file: valid_csv_file }
        }.to change(Csv2db::Property, :count).by(3)

        expect(response).to redirect_to(csv_insert_property_index_path)
        expect(flash[:notice]).to eq('登録・更新:3件、エラー:0件')
      end

      it 'creates properties with correct attributes' do
        post :csv_insert, params: { csv_file: valid_csv_file }

        # property1 (アパート):
        property1 = Csv2db::Property.find_by(id: 1)
        expect(property1).to be_present
        expect(property1.name).to eq('テスト物件1')
        expect(property1.address).to eq('東京都新宿区')
        expect(property1.room_number).to eq('101')
        expect(property1.rent).to eq(100000)
        expect(property1.area).to eq(30.0)
        expect(property1.building_type).to eq('apartment')

        # property2 (マンション):
        property2 = Csv2db::Property.find_by(id: 2)
        expect(property2).to be_present
        expect(property2.name).to eq('テスト物件2')
        expect(property2.address).to eq('東京都渋谷区')
        expect(property2.room_number).to eq('201')
        expect(property2.rent).to eq(150000)
        expect(property2.area).to eq(40.0)
        expect(property2.building_type).to eq('mansion')

        # property3 (一戸建て):
        property3 = Csv2db::Property.find_by(id: 3)
        expect(property3).to be_present
        expect(property3.name).to eq('テスト物件3')
        expect(property3.address).to eq('大阪府大阪市')
        expect(property3.room_number).to be_blank # 一戸建ては部屋番号なし
        expect(property3.rent).to eq(200000)
        expect(property3.area).to eq(80.0)
        expect(property3.building_type).to eq('house')
      end
    end

    context 'when CSV contains invalid data' do
      it 'skips invalid records and shows error messages' do
        expect {
          post :csv_insert, params: { csv_file: invalid_csv_file }
        }.to change(Csv2db::Property, :count).by(1) # Only valid record is imported

        expect(response).to redirect_to(csv_insert_property_index_path)
        expect(flash[:notice]).to eq('登録・更新:1件、エラー:2件')
        expect(flash[:alert_messages]).to be_present
        expect(flash[:alert_messages].size).to eq(2)
      end

      it 'includes specific error messages for invalid building types' do
        post :csv_insert, params: { csv_file: invalid_csv_file }

        error_messages = flash[:alert_messages]
        expect(error_messages.first).to include('「無効な種類」は許可された建物の種類（アパート、一戸建て、マンション）ではありません')
        expect(error_messages.second).to include('物件名 を入力してください')
      end
    end

    context 'when updating existing properties' do
      before do
        # Create existing property
        Csv2db::Property.create!(
          id: 1,
          name: '既存物件',
          address: '既存住所',
          room_number: '999',
          rent: '50000',
          area: '20',
          building_type: 'mansion'
        )
      end

      it 'updates existing properties instead of creating duplicates' do
        expect {
          post :csv_insert, params: { csv_file: valid_csv_file }
        }.to change(Csv2db::Property, :count).by(2) # 2 new records, 1 updated

        updated_property = Csv2db::Property.find(1)
        expect(updated_property.name).to eq('テスト物件1')
        expect(updated_property.building_type).to eq('apartment')
      end
    end

    context 'when handling large datasets' do
      let(:large_csv_content) do
        header = "ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類\n"
        rows = (1..2345).map do |i|
          "#{i},物件#{i},住所#{i},#{i},#{i * 1000},#{i},アパート"
        end.join("\n")
        header + rows
      end

      let(:large_csv_file) do
        file = Tempfile.new([ 'large_properties', '.csv' ])
        file.write(large_csv_content)
        file.rewind
        fixture_file_upload(file.path, 'text/csv')
      end

      it 'processes large datasets in batches' do
        expect {
          post :csv_insert, params: { csv_file: large_csv_file }
        }.to change(Csv2db::Property, :count).by(2345)

        expect(flash[:notice]).to eq('登録・更新:2345件、エラー:0件')
      end
    end

    context 'when limiting error message display' do
      let(:many_errors_csv_content) do
        header = "ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類\n"
        rows = (1..25).map do |i|
          "#{i},,住所#{i},#{i},#{i * 1000},#{i},アパート" # Missing name
        end.join("\n")
        header + rows
      end

      let(:many_errors_csv_file) do
        file = Tempfile.new([ 'many_errors_properties', '.csv' ])
        file.write(many_errors_csv_content)
        file.rewind
        fixture_file_upload(file.path, 'text/csv')
      end

      it 'limits displayed error messages to 20 and shows undisplayed count' do
        post :csv_insert, params: { csv_file: many_errors_csv_file }

        expect(flash[:alert_messages]&.size).to eq(20)
        expect(flash[:undisplayed_errors]).to eq('他に 5 件のエラーがあります...CSVファイルを確認してください。')
        expect(flash[:notice]).to eq('登録・更新:0件、エラー:25件')
      end
    end

    context 'when an exception occurs' do
      before do
        allow(CSV).to receive(:foreach).and_raise(StandardError.new('CSV parsing error'))
      end

      it 'handles exceptions gracefully' do
        post :csv_insert, params: { csv_file: valid_csv_file }

        expect(response).to redirect_to(csv_insert_property_index_path)
        expect(flash[:alert]).to include('PropertyController#csv_insert処理中にエラーが発生しました')
        expect(flash[:alert]).to include('CSV parsing error')
      end

      context 'in development environment' do
        before do
          allow(Rails.env).to receive(:development?).and_return(true)
        end

        it 'includes backtrace in error message' do
          post :csv_insert, params: { csv_file: valid_csv_file }

          expect(flash[:alert]).to include('CSV parsing error')
          expect(flash[:alert]).to include("\n") # Backtrace
        end
      end
    end

    context 'when handling empty CSV file' do
      let(:empty_csv_file) do
        fixture_file_upload(Rails.root.join('spec/fixtures/files/empty_properties.csv'), 'text/csv')
      end

      it 'handles empty CSV file gracefully' do
        expect {
          post :csv_insert, params: { csv_file: empty_csv_file }
        }.not_to change(Csv2db::Property, :count)

        expect(response).to redirect_to(csv_insert_property_index_path)
        expect(flash[:notice]).to eq('登録・更新:0件、エラー:0件')
      end
    end

    context 'when apartment is missing room number' do
      let(:apartment_missing_room_file) do
        fixture_file_upload(Rails.root.join('spec/fixtures/files/apartment_missing_room.csv'), 'text/csv')
      end

      it 'validates room number requirement for apartments' do
        expect {
          post :csv_insert, params: { csv_file: apartment_missing_room_file }
        }.to change(Csv2db::Property, :count).by(1) # Only mansion should be saved

        expect(flash[:notice]).to eq('登録・更新:1件、エラー:1件')
        expect(flash[:alert_messages]).to be_present

        apartment_error = flash[:alert_messages].find { |msg| msg.include?('ユニークID 8') }
        expect(apartment_error).to include('部屋番号')
      end
    end

    context 'when database transaction fails' do
      before do
        # Mock upsert_all to raise an error
        allow(Csv2db::Property).to receive(:upsert_all).and_raise(ActiveRecord::StatementInvalid.new('Database error'))
      end

      it 'handles database errors gracefully' do
        post :csv_insert, params: { csv_file: valid_csv_file }

        expect(response).to redirect_to(csv_insert_property_index_path)
        expect(flash[:alert]).to include('PropertyController#csv_insert処理中にエラーが発生しました')
        expect(flash[:alert]).to include('Database error')
      end
    end
  end

  describe 'constants' do
    it 'has correct BUILDING_TYPE_MAP' do
      expected_map = {
        'アパート' => 0,
        'マンション' => 2,
        '一戸建て' => 1
      }
      expect(PropertyController::BUILDING_TYPE_MAP).to eq(expected_map)
    end
  end
end
