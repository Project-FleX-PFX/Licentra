# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProductDAO do
  let(:valid_attributes) do
    Fabricate.attributes_for(:product)
  end
  let!(:product1) { Fabricate(:product, product_name: 'Test Product 1') }
  let!(:product2) { Fabricate(:product, product_name: 'Test Product 2') }

  describe '.create' do
    context 'with valid attributes' do
      it 'creates a new product' do
        expect do
          described_class.create(valid_attributes)
        end.to change(Product, :count).by(1)
      end

      it 'returns the created product object', :aggregate_failures do
        product = described_class.create(valid_attributes)
        expect(product).to be_a(Product)
        expect(product.product_name).to eq(valid_attributes[:product_name])
        expect(product.pk).not_to be_nil
      end

      it 'logs the creation' do
        allow(described_class).to receive(:log_created)
        product = described_class.create(valid_attributes)
        expect(described_class).to have_received(:log_created).with(product)
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { product_name: nil } }

      it 'does not create a new product' do
        expect do
          described_class.create(invalid_attributes)
        rescue StandardError
          # Expected error
        end.not_to change(Product, :count)
      end

      it 'raises a ValidationError with correct details', :aggregate_failures do
        expect do
          described_class.create(invalid_attributes)
        end.to raise_error(DAO::ValidationError) do |error|
          expect(error.message).to match(/creating product/i)
          expect(error.errors).to have_key(:product_name)
        end
      end
    end
  end

  describe '.find_by_name' do
    it 'returns the product when found' do
      product = described_class.find_by_name('Test Product 1')
      expect(product).to eq(product1)
    end

    it 'returns nil when product not found' do
      expect(described_class.find_by_name('Nonexistent Product')).to be_nil
    end

    it 'returns nil when name is nil or empty' do
      expect(described_class.find_by_name(nil)).to be_nil
      expect(described_class.find_by_name('')).to be_nil
    end

    it 'logs when product is found' do
      allow(described_class).to receive(:log_product_found_by_name)
      described_class.find_by_name('Test Product 1')
      expect(described_class).to have_received(:log_product_found_by_name).with('Test Product 1', product1)
    end

    it 'does not log when product is not found' do
      allow(described_class).to receive(:log_product_found_by_name)
      described_class.find_by_name('Nonexistent Product')
      expect(described_class).not_to have_received(:log_product_found_by_name)
    end
  end

  describe '.find_by_name!' do
    it 'returns the product when found' do
      product = described_class.find_by_name!('Test Product 1')
      expect(product).to eq(product1)
    end

    it 'raises RecordNotFound when product not found' do
      expect do
        described_class.find_by_name!('Nonexistent Product')
      end.to raise_error(DAO::RecordNotFound)
    end
  end

  describe '.delete' do
    context 'when product has no licenses' do
      let!(:product_to_delete) { Fabricate(:product) }

      it 'removes the product from the database' do
        expect do
          described_class.delete(product_to_delete.pk)
        end.to change(Product, :count).by(-1)
        expect(Product[product_to_delete.pk]).to be_nil
      end

      it 'returns true' do
        expect(described_class.delete(product_to_delete.pk)).to be true
      end

      it 'logs the deletion' do
        allow(described_class).to receive(:log_deleted)
        described_class.delete(product_to_delete.pk)
        expect(described_class).to have_received(:log_deleted).with(product_to_delete)
      end
    end

    context 'when product has licenses' do
      let!(:product_with_licenses) { Fabricate(:product) }

      before do
        Fabricate(:license, product: product_with_licenses)
      end

      it 'does not delete the product' do
        expect do
          described_class.delete(product_with_licenses.pk)
        rescue StandardError
          # Expected error
        end.not_to change(Product, :count)
      end

      it 'raises a DatabaseError' do
        expect do
          described_class.delete(product_with_licenses.pk)
        end.to raise_error(DAO::ProductManagementError, /associated licenses/i)
      end
    end

    context 'when product does not exist' do
      it 'raises a RecordNotFound error' do
        expect do
          described_class.delete(99_999)
        end.to raise_error(DAO::RecordNotFound)
      end
    end
  end
end
