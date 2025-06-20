# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

module PdfExporters
  module LogExporter
    # --- Design Constants ---
    DEFAULT_FONT = 'Helvetica'
    BRAND_COLOR = '0D47A1'
    HEADER_TEXT_COLOR = 'FFFFFF'
    BODY_TEXT_COLOR = '333333'
    ROW_COLOR_EVEN = 'FFFFFF'
    ROW_COLOR_ODD = 'E3F2FD'
    FOOTER_HEIGHT = 35 # Reserve space for footer

    # Generates the PDF for Assignment Logs
    def self.generate_assignment_logs_pdf(logs, filters_applied, current_user_info)
      # Initialize PDF in landscape mode for better table layout
      pdf = Prawn::Document.new(page_size: 'A4', margin: [40, 50, 40, 50], page_layout: :landscape)
      setup_fonts(pdf)

      title = 'Assignment Log Export'
      header(pdf, title, filters_applied, current_user_info)

      if logs.empty?
        pdf.fill_color BODY_TEXT_COLOR
        pdf.text 'No assignment logs found for the selected criteria.', style: :italic, align: :center
      else
        table_data = build_assignment_table_data(logs)

        # Define column widths as percentages of the available page width
        column_widths = {
          0 => pdf.bounds.width * 0.16, # Timestamp
          1 => pdf.bounds.width * 0.15, # User
          2 => pdf.bounds.width * 0.12, # Action
          3 => pdf.bounds.width * 0.15, # License
          4 => pdf.bounds.width * 0.10, # Assignment-ID
          5 => pdf.bounds.width * 0.32  # Details
        }

        # Draw the table with reserved space for footer
        pdf.fill_color BODY_TEXT_COLOR
        pdf.bounding_box([pdf.bounds.left, pdf.cursor],
                         width: pdf.bounds.width,
                         height: pdf.cursor - FOOTER_HEIGHT) do
          pdf.table(table_data,
                    header: true,
                    width: pdf.bounds.width,
                    column_widths: column_widths,
                    row_colors: [ROW_COLOR_EVEN, ROW_COLOR_ODD],
                    cell_style: {
                      size: 8,
                      padding: [5, 6, 5, 6],
                      border_width: 0.5,
                      border_color: 'DDDDDD',
                    }) do
            # Style the header row
            row(0).background_color = BRAND_COLOR
            row(0).text_color = HEADER_TEXT_COLOR
            row(0).font_style = :bold
          end
        end
      end

      footer(pdf)
      pdf.render
    end

    # Generates the PDF for Security Logs
    def self.generate_security_logs_pdf(logs, filters_applied, current_user_info)
      # Initialize PDF in landscape mode
      pdf = Prawn::Document.new(page_size: 'A4', margin: [40, 50, 40, 50], page_layout: :landscape)
      setup_fonts(pdf)

      title = 'Security Log Export'
      header(pdf, title, filters_applied, current_user_info)

      if logs.empty?
        pdf.fill_color BODY_TEXT_COLOR
        pdf.text 'No security logs found for the selected criteria.', style: :italic, align: :center
      else
        table_data = build_security_table_data(logs)

        # Define column widths as percentages
        column_widths = {
          0 => pdf.bounds.width * 0.18, # Timestamp
          1 => pdf.bounds.width * 0.15, # User
          2 => pdf.bounds.width * 0.12, # Action
          3 => pdf.bounds.width * 0.12, # Object
          4 => pdf.bounds.width * 0.43  # Details
        }

        # Draw the table with reserved space for footer
        pdf.fill_color BODY_TEXT_COLOR
        pdf.bounding_box([pdf.bounds.left, pdf.cursor],
                         width: pdf.bounds.width,
                         height: pdf.cursor - FOOTER_HEIGHT) do
          pdf.table(table_data,
                    header: true,
                    width: pdf.bounds.width,
                    column_widths: column_widths,
                    row_colors: [ROW_COLOR_EVEN, ROW_COLOR_ODD],
                    cell_style: {
                      size: 8,
                      padding: [5, 6, 5, 6],
                      border_width: 0.5,
                      border_color: 'DDDDDD'
                    }) do
            # Style the header row
            row(0).background_color = BRAND_COLOR
            row(0).text_color = HEADER_TEXT_COLOR
            row(0).font_style = :bold
          end
        end
      end

      footer(pdf)
      pdf.render
    end

    # --- Private Helper Methods ---
    private_class_method

    # Builds the data array for the assignment logs table
    def self.build_assignment_table_data(logs)
      headers = ['Timestamp (UTC)', 'User', 'Action', 'License', 'Assignment-ID', 'Details']
      table_data = [headers]

      logs.each do |log|
        assignment_id_match = log.details.match(/Assignment ID: (\d+)/)
        assignment_id = assignment_id_match ? assignment_id_match[1] : 'N/A'

        table_data << [
          log.log_timestamp.getutc.strftime('%Y-%m-%d %H:%M:%S'),
          "#{log.username} (ID: #{log.user_id})",
          log.action.gsub('_', ' ').capitalize,
          "#{log.license_name} (ID: #{log.license_id})",
          assignment_id,
          format_details_for_pdf(log.details)  # Hier die Formatierung anwenden
        ]
      end
      table_data
    end

    # Builds the data array for the security logs table
    def self.build_security_table_data(logs)
      headers = ['Timestamp (UTC)', 'User', 'Action', 'Object', 'Details']
      table_data = [headers]

      logs.each do |log|
        table_data << [
          log.log_timestamp.getutc.strftime('%Y-%m-%d %H:%M:%S'),
          "#{log.username}#{" (ID: #{log.user_id})" if log.user_id}",
          log.action.gsub('_', ' ').capitalize,
          log.object&.capitalize,
          format_details_for_pdf(log.details)  # Hier die Formatierung anwenden
        ]
      end
      table_data
    end

    # Sets up custom fonts for the PDF
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

    # Draws the standard header for each PDF
    def self.header(pdf, title, filters_applied_text, current_user_info)
      pdf.canvas do
        pdf.fill_color BRAND_COLOR
        pdf.fill_rectangle [pdf.bounds.left, pdf.bounds.top + 20], pdf.bounds.width, 20
        pdf.fill_color HEADER_TEXT_COLOR
        pdf.text_box title, at: [pdf.bounds.left + 10, pdf.bounds.top + 16], size: 10, style: :bold, height: 18,
                     valign: :center
      end
      pdf.move_down 30

      pdf.fill_color BODY_TEXT_COLOR
      pdf.text title, size: 16, style: :bold, align: :center
      pdf.move_down 10
      pdf.text "Exported by: #{current_user_info}", size: 8
      pdf.text "Exported at: #{Time.now.getlocal.strftime('%Y-%m-%d %H:%M:%S %Z')}", size: 8
      pdf.text "Filters Applied: #{filters_applied_text.empty? ? 'None' : filters_applied_text}", size: 8, style: :italic
      pdf.move_down 15
    end

    # Draws the footer with page numbers on each page
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

    # Converts quoted text to bold formatting for PDF inline format
    def self.format_details_for_pdf(details)
      # Replace single quotes around text with bold tags
      details.gsub(/'([^']+)'/, '\1')
             .gsub(/"([^"]+)"/, '\1')  # Also handle double quotes if needed
    end
  end
end
