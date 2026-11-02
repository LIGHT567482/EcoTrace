export function ReportPrintHeader() {
  return (
    <div className="print-brand">
      <img className="print-logo" src="/favicon.png" alt="EcoTrace mark" />
    </div>
  );
}

export function SaveReportPdfButton() {
  return (
    <button className="btn no-print" type="button" onClick={() => window.print()}>
      Save as PDF
    </button>
  );
}
