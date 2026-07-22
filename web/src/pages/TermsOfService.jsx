import React from 'react'
import { Link } from 'react-router-dom'
import { LegalLayout, LegalSection } from '../components/legal/LegalLayout'

const TOC = [
  { key: 'acceptance', label: 'Acceptance of Terms' },
  { key: 'the-service', label: 'The Service' },
  { key: 'not-gambling', label: 'Entertainment Only — Not Gambling' },
  { key: 'eligibility', label: 'Eligibility & Accounts' },
  { key: 'billing', label: 'Subscriptions & Billing' },
  { key: 'content', label: 'Your Content & Conduct' },
  { key: 'prohibited', label: 'Prohibited Activities' },
  { key: 'ip', label: 'Intellectual Property' },
  { key: 'results-data', label: 'Real Results & Third-Party Data' },
  { key: 'disclaimers', label: 'Disclaimers' },
  { key: 'liability', label: 'Limitation of Liability' },
  { key: 'termination', label: 'Termination' },
  { key: 'changes', label: 'Changes to These Terms' },
  { key: 'law', label: 'Governing Law' },
  { key: 'contact', label: 'Contact' },
]

export default function TermsOfService() {
  return (
    <LegalLayout eyebrow="Legal" title="Terms of Service" updated="July 22, 2026" toc={TOC}>
      <LegalSection id="acceptance" title="1. Acceptance of Terms">
        <p>
          These Terms of Service ("Terms") govern your access to and use of Mat Savvy (the "Service"). By creating an
          account or otherwise using the Service, you agree to be bound by these Terms and by our{' '}
          <Link to="/privacy" className="font-semibold text-gold-400 hover:text-gold-300">Privacy Policy</Link>,
          which is incorporated into these Terms by reference. If you do not agree, do not use the Service.
        </p>
      </LegalSection>

      <LegalSection id="the-service" title="2. The Service">
        <p>
          Mat Savvy is a wrestling fantasy and prediction platform. It lets users predict outcomes of real NCAA
          wrestling tournaments ("Bracket Challenge"), build salary-cap fantasy rosters for a single tournament
          ("Pick'em Showdown"), form private pools ("Groups"), and run season-long, draft-based fantasy leagues
          ("Fantasy Draft Leagues"), among other features we may add or remove over time. Full rules and scoring for
          each mode are published in our <Link to="/help" className="font-semibold text-gold-400 hover:text-gold-300">Help Center</Link>.
        </p>
      </LegalSection>

      <LegalSection id="not-gambling" title="3. Entertainment Only — Not Gambling">
        <p>
          <strong>Mat Savvy is purely for entertainment and bragging rights.</strong> There is no wagering, no
          entry fees tied to a chance of winning money or prizes, and no payout of any kind based on your rank,
          score, or performance anywhere on the Service. Paid subscriptions (see Section 5) purchase access to
          product features — additional entries and league-hosting tools — not a chance to win anything of monetary
          value. Nothing on the Service should be understood or represented as gambling, betting, or a game of
          chance for stakes.
        </p>
      </LegalSection>

      <LegalSection id="eligibility" title="4. Eligibility & Accounts">
        <ul>
          <li>You must be able to form a legally binding contract to create an account. The Service is not directed to, and we do not knowingly collect personal information from, children under 13.</li>
          <li>You must provide accurate account information and keep your password confidential. You're responsible for all activity under your account.</li>
          <li>One account per person. You may not share, sell, or transfer your account.</li>
          <li>We may suspend or terminate accounts that violate these Terms (see Section 12).</li>
        </ul>
      </LegalSection>

      <LegalSection id="billing" title="5. Subscriptions & Billing">
        <p>
          Mat Savvy offers a free tier and a paid Annual plan; current pricing and features are listed on our{' '}
          <Link to="/pricing" className="font-semibold text-gold-400 hover:text-gold-300">Pricing</Link> page.
        </p>
        <ul>
          <li>Payments are processed by Stripe. We never see or store your full card number.</li>
          <li>The Annual plan renews automatically at the then-current price unless you cancel before the renewal date. You can cancel any time from your account settings; cancellation stops future renewals but does not refund the current billing period.</li>
          <li>Fees are generally non-refundable except where required by law or at our discretion.</li>
          <li>We may change subscription pricing going forward; changes won't apply retroactively to a period you've already paid for.</li>
        </ul>
      </LegalSection>

      <LegalSection id="content" title="6. Your Content & Conduct">
        <p>
          You retain ownership of the profile information, bios, and picks you submit ("User Content"). By posting
          User Content that you mark public, you grant Mat Savvy a worldwide, royalty-free license to display it on
          the Service (for example, on leaderboards and public profile pages) for as long as your account exists or
          until you make that content private again.
        </p>
      </LegalSection>

      <LegalSection id="prohibited" title="7. Prohibited Activities">
        <p>You agree not to:</p>
        <ul>
          <li>Create multiple accounts to manipulate leaderboards, drafts, or league play;</li>
          <li>Scrape, reverse-engineer, or use automated tools against the Service without our written permission;</li>
          <li>Impersonate another person or misrepresent your affiliation with anyone;</li>
          <li>Upload content that is unlawful, harassing, or infringes someone else's rights;</li>
          <li>Interfere with the Service's normal operation or attempt to access accounts or data that aren't yours;</li>
          <li>Use the Service for any purpose prohibited by applicable law.</li>
        </ul>
      </LegalSection>

      <LegalSection id="ip" title="8. Intellectual Property">
        <p>
          The Mat Savvy name, logo, and the Service's design, code, and compiled results/statistics presentations
          are owned by Mat Savvy or its licensors and protected by applicable intellectual property laws. These
          Terms don't grant you any right to use our branding except as necessary to use the Service as intended.
        </p>
      </LegalSection>

      <LegalSection id="results-data" title="9. Real Results & Third-Party Data">
        <p>
          Scoring depends on real-world wrestling results that we source and compile from public sources. We work
          to keep this data accurate and current but don't guarantee it's error-free or that it will never require
          correction after the fact (which may change a score or rank previously shown). Official results from the
          governing athletic bodies and event organizers always control over anything shown on the Service.
        </p>
      </LegalSection>

      <LegalSection id="disclaimers" title="10. Disclaimers">
        <p>
          The Service is provided "as is" and "as available," without warranties of any kind, express or implied,
          including merchantability, fitness for a particular purpose, and non-infringement. We don't guarantee the
          Service will be uninterrupted, secure, or error-free.
        </p>
      </LegalSection>

      <LegalSection id="liability" title="11. Limitation of Liability">
        <p>
          To the maximum extent permitted by law, Mat Savvy will not be liable for any indirect, incidental,
          special, consequential, or punitive damages, or any loss of data or goodwill, arising from your use of
          the Service. Our total liability for any claim relating to the Service is limited to the amount you paid
          us, if any, in the 12 months before the claim arose.
        </p>
      </LegalSection>

      <LegalSection id="termination" title="12. Termination">
        <p>
          You may stop using the Service and close your account at any time. We may suspend or terminate your
          access if you violate these Terms, or at our discretion to protect the Service or other users, with
          notice where reasonably practical. Sections that by their nature should survive termination (including
          Sections 3, 8, 10, 11, and 14) will survive.
        </p>
      </LegalSection>

      <LegalSection id="changes" title="13. Changes to These Terms">
        <p>
          We may update these Terms from time to time. If we make material changes, we'll update the "Last
          updated" date above and, where appropriate, notify you through the Service. Continuing to use the Service
          after changes take effect means you accept the updated Terms.
        </p>
      </LegalSection>

      <LegalSection id="law" title="14. Governing Law">
        <p>
          These Terms are governed by the laws of the Commonwealth of Virginia, without regard to its conflict-of-laws
          principles, and any dispute arising under these Terms will be resolved in the state or federal courts
          located in Virginia.
        </p>
      </LegalSection>

      <LegalSection id="contact" title="15. Contact">
        <p>
          Questions about these Terms? Reach us at{' '}
          <a href="mailto:garrett@localmediachamps.com" className="font-semibold text-gold-400 hover:text-gold-300">
            garrett@localmediachamps.com
          </a>.
        </p>
      </LegalSection>
    </LegalLayout>
  )
}
