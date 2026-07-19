# Concern for stripping leading whitespace from string/text attributes
# before validation, so accidental leading spaces typed on create/edit
# forms don't get saved (e.g. " My Song" -> "My Song").
module StripsWhitespace
  extend ActiveSupport::Concern

  included do
    before_validation :strip_leading_whitespace
  end

  private

  def strip_leading_whitespace
    self.class.columns.each do |column|
      next unless [:string, :text].include?(column.type)

      value = self[column.name]
      self[column.name] = value.lstrip if value.is_a?(String)
    end
  end
end
