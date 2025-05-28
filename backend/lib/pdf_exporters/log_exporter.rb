# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

module PdfExporters
  module LogExporter
    DEFAULT_FONT = 'Helvetica'
    BRAND_COLOR = '2551D9'
    HEADER_TEXT_COLOR = 'FFFFFF'
    BODY_TEXT_COLOR = '000000'
    ROW_COLOR_EVEN = 'FFFFFF'
    ROW_COLOR_ODD = 'EFEFEF'

    def self.generate_assignment_logs_pdf(logs, filters_applied, current_user_info)
      pdf = Prawn::Document.new(page_size: 'A4', margin: [40, 50, 40, 50], page_layout: :landscape)
      setup_fonts(pdf)

      title = 'Assignment Log Export'
      header(pdf, title, filters_applied, current_user_info)

      if logs.empty?
        pdf.fill_color BODY_TEXT_COLOR
        pdf.text 'No assignment logs found for the selected criteria.', style: :italic, align: :center
      else
        table_data = [
          [
            { content: 'Timestamp', font_style: :bold },
            { content: 'User', font_style: :bold },
            { content: 'Action', font_style: :bold },
            { content: 'License', font_style: :bold },
            { content: 'Assignment-ID', font_style: :bold },
            { content: 'Details', font_style: :bold }
          ]
        ]

        logs.each do |log|
          assignment_id_match = log.details.match(/Assignment ID: (\d+)/)
          assignment_id = assignment_id_match ? assignment_id_match[1] : 'N/A'

          table_data << [
            log.log_timestamp.getlocal.strftime('%Y-%m-%d %H:%M:%S %Z'),
            "#{log.username} (ID: #{log.user_id})",
            log.action.gsub('_', ' ').capitalize,
            "#{log.license_name} (ID: #{log.license_id})",
            assignment_id,
            { content: log.details, size: 7 }
          ]
        end

        pdf.fill_color BODY_TEXT_COLOR
        pdf.table(table_data,
                  header: true,
                  width: pdf.bounds.width,
                  row_colors: [ROW_COLOR_EVEN, ROW_COLOR_ODD],
                  cell_style: { size: 8, padding: [3, 5, 3, 5], border_width: 0.5 }) do
          row(0).background_color = BRAND_COLOR
          row(0).text_color = HEADER_TEXT_COLOR
        end
      end

      footer(pdf)
      pdf.render
    end

    def self.generate_security_logs_pdf(logs, filters_applied, current_user_info)
      pdf = Prawn::Document.new(page_size: 'A4', margin: [40, 50, 40, 50], page_layout: :landscape)
      setup_fonts(pdf)

      title = 'Security Log Export'
      header(pdf, title, filters_applied, current_user_info)

      if logs.empty?
        pdf.fill_color BODY_TEXT_COLOR
        pdf.text 'No security logs found for the selected criteria.', style: :italic, align: :center
      else
        table_data = [
          [
            { content: 'Timestamp', font_style: :bold },
            { content: 'User', font_style: :bold },
            { content: 'Action', font_style: :bold },
            { content: 'Object', font_style: :bold },
            { content: 'Details', font_style: :bold }
          ]
        ]

        logs.each do |log|
          table_data << [
            log.log_timestamp.getlocal.strftime('%Y-%m-%d %H:%M:%S %Z'),
            "#{log.username}#{" (ID: #{log.user_id})" if log.user_id}",
            log.action.gsub('_', ' ').capitalize,
            log.object&.capitalize,
            { content: log.details, size: 7 }
          ]
        end

        pdf.fill_color BODY_TEXT_COLOR
        pdf.table(table_data,
                  header: true,
                  width: pdf.bounds.width,
                  row_colors: [ROW_COLOR_EVEN, ROW_COLOR_ODD],
                  cell_style: { size: 8, padding: [3, 5, 3, 5], border_width: 0.5 }) do
          row(0).background_color = BRAND_COLOR
          row(0).text_color = HEADER_TEXT_COLOR
        end
      end

      footer(pdf)
      pdf.render
    end

    def self.setup_fonts(pdf)
      pdf.font_families.update(
        'NotoSans' => {
          normal: File.expand_path('../../public/fonts/NotoSans-Regular.ttf', __dir__),
          italic: File.expand_path('../../public/fonts/NotoSans-Italic.ttf', __dir__),
          bold: File.expand_path('../../public/fonts/NotoSans-Bold.ttf', __dir__),
          bold_italic: File.expand_path('../../public/fonts/NotoSans-BoldItalic.ttf', __dir__)
        }
      )
      pdf.font 'NotoSans'
    rescue Prawn::Errors::UnknownFont
      warn 'NotoSans font not found, falling back to Helvetica for PDF export.'
      pdf.font DEFAULT_FONT
    end

    def self.header(pdf, title, filters_applied_text, current_user_info)
      pdf.canvas do
        pdf.fill_color BRAND_COLOR
        pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top + 25], pdf.bounds.width, 25
        pdf.fill_color HEADER_TEXT_COLOR
        pdf.text_box title, at: [pdf.bounds.left + 10, pdf.bounds.top + 20], size: 12, style: :bold
      end
      pdf.move_down 35

      pdf.fill_color BODY_TEXT_COLOR
      pdf.text title, size: 18, style: :bold, align: :center
      pdf.move_down 10
      pdf.text "Exported by: #{current_user_info}", size: 8
      pdf.text "Exported at: #{Time.now.getlocal.strftime('%Y-%m-%d %H:%M:%S %Z')}", size: 8
      pdf.text "Filters Applied: #{filters_applied_text.empty? ? 'None' : filters_applied_text}", size: 8
      pdf.move_down 15
    end

    def self.footer(pdf)
      pdf.page_count.times do |i|
        pdf.go_to_page(i + 1)
        pdf.bounding_box([pdf.bounds.left, pdf.bounds.bottom + 25], width: pdf.bounds.width) do
          pdf.move_down 5
          pdf.fill_color BODY_TEXT_COLOR
          pdf.text "Page #{i + 1} of #{pdf.page_count}", align: :center, size: 8
        end
      end
    end
  end
end
