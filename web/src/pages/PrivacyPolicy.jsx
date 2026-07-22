import React from 'react'
import { Link } from 'react-router-dom'
import { LegalLayout, LegalSection } from '../components/legal/LegalLayout'

const TOC = [
  { key: 'overview', label: 'Overview' },
  { key: 'collect', label: 'Information We Collect' },
  { key: 'use', label: 'How We Use Information' },
  { key: 'share', label: 'How We Share Information' },
  { key: 'storage', label: 'Local Storage & Tracking' },
  { key: 'retention', label: 'Data Retention' },
  { key: 'choices', label: 'Your Choices & Rights' },
  { key: 'children', label: "Children's Privacy" },
  { key: 'security', label: 'Security' },
  { key: 'changes', label: 'Changes to This Policy' },
  { key: 'contact', label: 'Contact' },
]

export default function PrivacyPolicy() {
  return (
    <LegalLayout eyebrow="Legal" title="Privacy Policy" updated="July 22, 2026" toc={TOC}>
      <LegalSection id="overview" title="1. Overview">
        <p>
          This Privacy Policy explains what information Mat Savvy collects, how we use it, and the choices you have.
          It applies to your use of the Service and should be read alongside our{' '}
          <Link to="/terms" className="font-semibold text-gold-400 hover:text-gold-300">Terms of Service</Link>.
        </p>
      </LegalSection>

      <LegalSection id="collect" title="2. Information We Collect">
        <p><strong>Account information</strong> you give us directly:</p>
        <ul>
          <li>Name, email address, username, and password (stored securely — we never store or display your plain-text password);</li>
          <li>Optional profile details you choose to add: display name, avatar image, bio, favorite school;</li>
          <li>Your bracket/pick'em picks, group and league memberships, and the visibility settings you choose for each (e.g. whether an entry is public, whether you appear on public leaderboards).</li>
        </ul>
        <p><strong>Billing information</strong> — if you subscribe to a paid plan, our payment processor Stripe collects your payment details directly. We receive only your subscription status, not your full card number.</p>
        <p><strong>Usage information</strong> — standard technical data such as IP address, browser type, and pages visited, generated automatically as part of operating the Service.</p>
      </LegalSection>

      <LegalSection id="use" title="3. How We Use Information">
        <ul>
          <li>To create and maintain your account, and to score and display your entries, leaderboards, and league standings;</li>
          <li>To communicate with you — account verification, password resets, and service-related notifications;</li>
          <li>To process payments for paid plans;</li>
          <li>To maintain the security and integrity of the Service (e.g. detecting abuse or fraud);</li>
          <li>To improve and develop the Service.</li>
        </ul>
      </LegalSection>

      <LegalSection id="share" title="4. How We Share Information">
        <p><strong>We do not sell your personal information.</strong> We share information only with:</p>
        <ul>
          <li><strong>Stripe</strong>, to process subscription payments;</li>
          <li><strong>Xano</strong>, our backend database and hosting provider, which stores and processes data on our behalf to run the Service;</li>
          <li>Other users, but only what you've chosen to make visible — your public profile, public entries, and leaderboard appearance are governed entirely by your own settings (see Section 7);</li>
          <li>Law enforcement or other parties when required by law, or to protect the rights, property, or safety of Mat Savvy, our users, or the public.</li>
        </ul>
      </LegalSection>

      <LegalSection id="storage" title="5. Local Storage & Tracking">
        <p>
          We use your browser's local storage to keep you signed in between visits — this holds your session token,
          not third-party advertising identifiers. Mat Savvy does not use third-party advertising or analytics
          trackers.
        </p>
      </LegalSection>

      <LegalSection id="retention" title="6. Data Retention">
        <p>
          We retain your account information for as long as your account is active. If you delete your account, we
          remove or anonymize your personal information within a reasonable period, except where we're required to
          retain certain records (for example, billing history) by law.
        </p>
      </LegalSection>

      <LegalSection id="choices" title="7. Your Choices & Rights">
        <p>You control most of your own visibility directly from your account:</p>
        <ul>
          <li><strong>Per-entry public/private toggle</strong> — decide whether any specific bracket/pick'em entry can be viewed by other users;</li>
          <li><strong>Leaderboard visibility</strong> — opt out of appearing on public leaderboards entirely, and choose whether your display name or username is shown when visible;</li>
          <li><strong>Public submissions list</strong> — control whether your profile shows a summary of your public entries;</li>
          <li><strong>Profile fields</strong> — edit or clear your name, avatar, bio, and favorite school any time from Profile settings.</li>
        </ul>
        <p>
          To request a copy of your data, or to request that we delete your account and associated personal
          information, email us at{' '}
          <a href="mailto:garrett@localmediachamps.com" className="font-semibold text-gold-400 hover:text-gold-300">
            garrett@localmediachamps.com
          </a>.
        </p>
      </LegalSection>

      <LegalSection id="children" title="8. Children's Privacy">
        <p>
          The Service is not directed to children under 13, and we do not knowingly collect personal information
          from children under 13. If you believe a child has provided us personal information, contact us and we'll
          delete it.
        </p>
      </LegalSection>

      <LegalSection id="security" title="9. Security">
        <p>
          We use industry-standard measures to protect your information, including encrypted password storage and
          secure data transmission. No method of transmission or storage is 100% secure, and we can't guarantee
          absolute security.
        </p>
      </LegalSection>

      <LegalSection id="changes" title="10. Changes to This Policy">
        <p>
          We may update this Privacy Policy from time to time. Material changes will be reflected in the "Last
          updated" date above, and where appropriate, we'll notify you through the Service.
        </p>
      </LegalSection>

      <LegalSection id="contact" title="11. Contact">
        <p>
          Questions about this Privacy Policy? Reach us at{' '}
          <a href="mailto:garrett@localmediachamps.com" className="font-semibold text-gold-400 hover:text-gold-300">
            garrett@localmediachamps.com
          </a>.
        </p>
      </LegalSection>
    </LegalLayout>
  )
}
