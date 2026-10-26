import { Link } from 'react-router-dom'

import { Card } from '../components/ui'

/** Privacy policy for the BridgeGrant iPhone/Android apps and this website. */
export function PrivacyPage() {
  return (
    <div className="page narrow">
      <h1>Privacy Policy</h1>
      <p className="muted">Effective October 25, 2026</p>

      <p>
        BridgeGrant helps South Carolina nonprofits find funders by showing public IRS grant records. This policy
        covers the BridgeGrant iPhone and Android apps and this website. You can use every part of BridgeGrant without
        an account, and we don't show ads, use analytics or tracking tools, sell your information, or collect your
        location or contacts.
      </p>

      <Card title="What we collect and why">
        <h3>Help requests</h3>
        <p>
          If you send a request on the Help page, we collect what you enter: your name, email address, phone number (if
          you give one), your nonprofit's name and stage, the kinds of help you need, and your message. We use it only
          to reply to you and to connect you with resources. It is stored in our database (Supabase, hosted in the
          United States) and emailed to the BridgeGrant team through our email service (Resend).
        </p>

        <h3>Questions in the Ask tab (iPhone app)</h3>
        <p>
          When you ask a question, the text of your question and the earlier messages in that conversation are sent to
          our server and to OpenAI, which writes the answer using grant records our server looks up. Your questions
          aren't linked to your name or any account. OpenAI processes them under its API data policies and may keep them
          for a limited time. Please don't include personal or sensitive information in your questions.
        </p>

        <h3>Daily question limits</h3>
        <p>
          To keep the Ask tab available for everyone, we count questions per day using your IP address and a random ID
          the app creates each time it opens. These counts are used only for that limit and are deleted automatically
          after about a week.
        </p>

        <h3>Settings on this website</h3>
        <p>
          The website remembers your light or dark mode and your county choice in your own browser (local storage). That
          information never leaves your device.
        </p>
      </Card>

      <Card title="Grant records">
        <p>
          The grant data in BridgeGrant comes from public IRS Form 990 and 990-PF filings, published by the Urban
          Institute's National Center for Charitable Statistics (NCCS). These filings are public records about
          organizations. Some private-foundation filings list grants to named individuals, such as scholarships; those
          names appear as they were reported to the IRS. If you believe a record about you should be removed, contact us
          as described below.
        </p>
      </Card>

      <Card title="Sharing">
        <p>
          We don't sell or rent personal information. We share it only with the service providers named above
          (Supabase for storage, Resend for email, OpenAI for Ask answers) so they can provide those services, or when
          the law requires it.
        </p>
      </Card>

      <Card title="Children">
        <p>
          BridgeGrant is meant for nonprofit leaders and volunteers. It isn't directed at children under 13, and we don't
          knowingly collect personal information from them. If you think a child has sent us information, contact us and
          we'll delete it.
        </p>
      </Card>

      <Card title="Your choices">
        <p>
          You can ask us to see, correct, or delete the information you sent in a help request. We keep help requests
          only as long as needed to respond and follow up, and delete them sooner if you ask.
        </p>
      </Card>

      <Card title="Contact us">
        <p>
          For privacy questions or deletion requests, send a request from the <Link to="/help">Help page</Link> and
          choose "Something else". Tell us the email address you used so we can find your request.
        </p>
      </Card>

      <p className="muted small">
        If we change this policy, we'll update it on this page and change the effective date above.
      </p>
    </div>
  )
}
