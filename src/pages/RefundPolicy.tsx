

const companyName = import.meta.env.VITE_COMPANY_NAME;
const contactEmail = import.meta.env.VITE_CONTACT_EMAIL;

function RefundPolicy() {
    return (
        <>
            <title>Cancellation & Refund Policy | {companyName}</title>
            <div className="container mx-auto px-4 py-8 prose lg:prose-xl">
                <h1>Cancellation & Refund Policy</h1>

                <h2>Book Visit Payments</h2>
                <p>All booking payments are <strong>non-refundable</strong>.</p>

                <h2>General Cancellation Terms</h2>
                <ul>
                    <li>Cancellation refunds are added only to the website wallet (non-withdrawable).</li>
                    <li>Customers must review and agree to the terms before booking.</li>
                </ul>

                <h2>Cancellation Requests</h2>
                <p>Cancellation can be requested via:</p>
                <ul>
                    <li>Email: <a href={`mailto:${contactEmail}`}>{contactEmail}</a></li>
                    <li>Online cancellation option (where available)</li>
                </ul>
                <p>Once confirmed, cancellation is final and cannot be reversed.</p>
            </div>
        </>
    );
}

export default RefundPolicy;