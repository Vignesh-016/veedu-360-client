

const companyName = import.meta.env.VITE_COMPANY_NAME;

function DeliveryPolicy() {
    return (
        <>
            <title>Shipping & Delivery Policy | {companyName}</title>
            <div className="container mx-auto px-4 py-8 prose lg:prose-xl">
                <h1>Shipping & Delivery Policy</h1>
                <p className="lead">(Applicable for services provided through the platform)</p>

                <ul>
                    <li>Service confirmation details are shared via email/SMS.</li>
                    <li>Service timelines vary based on location and requirement type.</li>
                    <li>Any delay in service will be communicated directly to the customer.</li>
                </ul>
            </div>
        </>
    );
}

export default DeliveryPolicy;