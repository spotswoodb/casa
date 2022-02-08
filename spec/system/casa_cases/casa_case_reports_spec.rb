require "rails_helper"
require "stringio"

RSpec.describe "volunteer downloads court reports for case", type: :system do
  let(:volunteer) { build(:volunteer) }
  let(:casa_case) { create(:casa_case, :with_one_court_order, casa_org: volunteer.casa_org) }
  let!(:case_assignment) { create(:case_assignment, volunteer: volunteer, casa_case: casa_case) }

  let!(:court_dates) do
    [10, 30, 31, 90].map { |n| create(:court_date, casa_case: casa_case, date: n.days.ago) }
  end

  let!(:reports) do
    [5, 11, 23, 44, 91].map do |n|
      report = CaseCourtReport.new(
          volunteer_id: volunteer.id,
          case_id: casa_case.id,
          path_to_template: "app/documents/templates/default_report_template.docx"
      )
      casa_case.court_reports.attach(io: StringIO.new(report.generate_to_string), filename: "report#{n}.docx")
      attached_report = casa_case.latest_court_report
      attached_report.created_at = n.days.ago
      attached_report.save!
      attached_report
    end
  end

  before { sign_in volunteer }

  it "views and downloads" do
    # timeline:
    # 1 Jan 2021 case contact
    # 10 Jan 2021 first court date
    # 20 Jan 2021 case contact
    # 2 Feb 2021 court date
    # 12 Feb 2021 case contact
    # 22 Feb 2021 is "now"
    # 3 March 2021 next court date (future)

    now = Date.new(2021, 1, 1)
    travel_to now do
      case_contact_1 = create(:case_contact, casa_case: casa_case, created_at: Date.new(1, 1, 2021))
      court_date_1 = create(:court_date, casa_case: casa_case, date: Date.new(1, 10, 2021))
      case_contact_2 = create(:case_contact, casa_case: casa_case, created_at: Date.new(1, 20, 2021))
      court_date_2 = create(:court_date, casa_case: casa_case, date: Date.new(2, 2, 2021))
      case_contact_3 = create(:case_contact, casa_case: casa_case, date: Date.new(2, 12, 2021))
      court_date_future = create(:court_date, casa_case: casa_case, date: Date.new(3, 3, 2021))

      volunteer = create(:volunteer)
      sign_in volunteer
      visit casa_case_path(casa_case)

      expect(page).to have_link(I18n.l(court_dates[1].date, format: :full, default: nil))
      expect(page).to have_text(I18n.l(court_dates[1].date, format: :full, default: nil))
    end

  end
end
