import React, { Suspense, lazy } from 'react'
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom'
import { useAuthStore } from './lib/store'
import AppShell from './components/layout/AppShell'
import AdminShell from './components/layout/AdminShell'
import { Toaster, Skeleton } from './components/ui'

/* Lazy pages — code-split per route */
const Landing = lazy(() => import('./pages/Landing'))
const Login = lazy(() => import('./pages/Login'))
const Register = lazy(() => import('./pages/Register'))
const ForgotPassword = lazy(() => import('./pages/ForgotPassword'))
const ResetPassword = lazy(() => import('./pages/ResetPassword'))
const VerifyEmail = lazy(() => import('./pages/VerifyEmail'))
const Tournaments = lazy(() => import('./pages/Tournaments'))
const Results = lazy(() => import('./pages/Results'))
const WrestlerProfile = lazy(() => import('./pages/WrestlerProfile'))
const Wrestlers = lazy(() => import('./pages/Wrestlers'))
const Teams = lazy(() => import('./pages/Teams'))
const TeamProfile = lazy(() => import('./pages/TeamProfile'))
const Pricing = lazy(() => import('./pages/Pricing'))
const TournamentHub = lazy(() => import('./pages/TournamentHub'))
const Predict = lazy(() => import('./pages/Predict'))
const Pickem = lazy(() => import('./pages/Pickem'))
const Dashboard = lazy(() => import('./pages/Dashboard'))
const EntryReview = lazy(() => import('./pages/EntryReview'))
const PickemEntryView = lazy(() => import('./pages/PickemEntryView'))
const Compare = lazy(() => import('./pages/Compare'))
const Leaderboard = lazy(() => import('./pages/Leaderboard'))
const CalendarPage = lazy(() => import('./pages/Calendar'))
const Help = lazy(() => import('./pages/Help'))
const TermsOfService = lazy(() => import('./pages/TermsOfService'))
const PrivacyPolicy = lazy(() => import('./pages/PrivacyPolicy'))
const DualMeets = lazy(() => import('./pages/DualMeets'))
const DualMeetDetail = lazy(() => import('./pages/DualMeetDetail'))
const DualMeetEntryView = lazy(() => import('./pages/DualMeetEntryView'))
const Groups = lazy(() => import('./pages/Groups'))
const GroupNew = lazy(() => import('./pages/GroupNew'))
const GroupDetail = lazy(() => import('./pages/GroupDetail'))
const Leagues = lazy(() => import('./pages/Leagues'))
const LeagueNew = lazy(() => import('./pages/LeagueNew'))
const LeagueDetail = lazy(() => import('./pages/LeagueDetail'))
const DraftRoom = lazy(() => import('./pages/DraftRoom'))
const LeagueLineup = lazy(() => import('./pages/LeagueLineup'))
const LeagueMatchup = lazy(() => import('./pages/LeagueMatchup'))
const LeagueCalendar = lazy(() => import('./pages/LeagueCalendar'))
const LeagueWaivers = lazy(() => import('./pages/LeagueWaivers'))
const LeagueTrades = lazy(() => import('./pages/LeagueTrades'))
const Profile = lazy(() => import('./pages/Profile'))
const MyRankings = lazy(() => import('./pages/MyRankings'))
const Rankings = lazy(() => import('./pages/Rankings'))
const UserProfile = lazy(() => import('./pages/UserProfile'))
const Notifications = lazy(() => import('./pages/Notifications'))
const AdminDashboard = lazy(() => import('./pages/admin/AdminDashboard'))
const TournamentWizard = lazy(() => import('./pages/admin/TournamentWizard'))
const AdminTournament = lazy(() => import('./pages/admin/AdminTournament'))
const AdminBuilder = lazy(() => import('./pages/admin/AdminBuilder'))
const AdminImport = lazy(() => import('./pages/admin/AdminImport'))
const AdminResults = lazy(() => import('./pages/admin/AdminResults'))
const AdminScoring = lazy(() => import('./pages/admin/AdminScoring'))
const AdminAnalytics = lazy(() => import('./pages/admin/AdminAnalytics'))
const AdminIngestion = lazy(() => import('./pages/admin/AdminIngestion'))
const AdminAudit = lazy(() => import('./pages/admin/AdminAudit'))
const AdminRankings = lazy(() => import('./pages/admin/AdminRankings'))
const NotFound = lazy(() => import('./pages/NotFound'))

function PageLoader() {
  return (
    <div className="space-y-4 pt-4">
      <Skeleton className="h-8 w-64" />
      <Skeleton className="h-48 w-full" />
      <Skeleton className="h-48 w-full" />
    </div>
  )
}

function RequireAuth({ children }) {
  const token = useAuthStore((s) => s.token)
  const location = useLocation()
  if (!token) return <Navigate to="/login" state={{ from: location.pathname }} replace />
  return children
}

function RequireAdmin({ children }) {
  const { token, user } = useAuthStore()
  if (!token) return <Navigate to="/login" replace />
  if (!user?.is_admin) return <Navigate to="/" replace />
  return children
}

// The marketing page is only for signed-out visitors - a logged-in user
// hitting "/" (e.g. clicking the logo, or just landing here after login)
// should see their dashboard instead, not the pitch page again.
function Root() {
  const token = useAuthStore((s) => s.token)
  if (token) return <Navigate to="/dashboard" replace />
  return <Landing />
}

export default function App() {
  return (
    <BrowserRouter>
      <Toaster />
      <Suspense fallback={<PageLoader />}>
        <Routes>
          <Route element={<AppShell />}>
            <Route path="/" element={<Root />} />
            <Route path="/login" element={<Login />} />
            <Route path="/register" element={<Register />} />
            <Route path="/forgot-password" element={<ForgotPassword />} />
            <Route path="/reset-password" element={<ResetPassword />} />
            <Route path="/verify-email" element={<VerifyEmail />} />
            <Route path="/tournaments" element={<Tournaments />} />
            <Route path="/results" element={<Results />} />
            <Route path="/wrestlers" element={<Wrestlers />} />
            <Route path="/wrestlers/:id" element={<WrestlerProfile />} />
            <Route path="/teams" element={<Teams />} />
            <Route path="/teams/:id" element={<TeamProfile />} />
            <Route path="/pricing" element={<Pricing />} />
            <Route path="/tournaments/:slug" element={<TournamentHub />} />
            <Route path="/tournaments/:slug/predict" element={<RequireAuth><Predict /></RequireAuth>} />
            <Route path="/tournaments/:slug/pickem" element={<RequireAuth><Pickem /></RequireAuth>} />
            <Route path="/leaderboard" element={<Leaderboard />} />
            <Route path="/calendar" element={<CalendarPage />} />
            <Route path="/help" element={<Help />} />
            <Route path="/terms" element={<TermsOfService />} />
            <Route path="/privacy" element={<PrivacyPolicy />} />
            <Route path="/dual-meets" element={<DualMeets />} />
            <Route path="/dual-meets/:id" element={<DualMeetDetail />} />
            <Route path="/dual-meet-entries/:id" element={<RequireAuth><DualMeetEntryView /></RequireAuth>} />
            <Route path="/dashboard" element={<RequireAuth><Dashboard /></RequireAuth>} />
            <Route path="/entries/:id/review" element={<RequireAuth><EntryReview /></RequireAuth>} />
            <Route path="/pickem-entries/:id" element={<RequireAuth><PickemEntryView /></RequireAuth>} />
            <Route path="/compare/:aId/:bId" element={<RequireAuth><Compare /></RequireAuth>} />
            <Route path="/groups" element={<RequireAuth><Groups /></RequireAuth>} />
            <Route path="/groups/new" element={<RequireAuth><GroupNew /></RequireAuth>} />
            <Route path="/groups/:id" element={<GroupDetail />} />
            <Route path="/leagues" element={<RequireAuth><Leagues /></RequireAuth>} />
            <Route path="/leagues/new" element={<RequireAuth><LeagueNew /></RequireAuth>} />
            <Route path="/leagues/:id" element={<RequireAuth><LeagueDetail /></RequireAuth>} />
            <Route path="/leagues/:id/draft" element={<RequireAuth><DraftRoom /></RequireAuth>} />
            <Route path="/leagues/:id/draft/:seasonWeekId" element={<RequireAuth><DraftRoom /></RequireAuth>} />
            <Route path="/leagues/:id/lineup" element={<RequireAuth><LeagueLineup /></RequireAuth>} />
            <Route path="/leagues/:id/matchup" element={<RequireAuth><LeagueMatchup /></RequireAuth>} />
            <Route path="/leagues/:id/calendar" element={<RequireAuth><LeagueCalendar /></RequireAuth>} />
            <Route path="/leagues/:id/waivers" element={<RequireAuth><LeagueWaivers /></RequireAuth>} />
            <Route path="/leagues/:id/trades" element={<RequireAuth><LeagueTrades /></RequireAuth>} />
            <Route path="/profile" element={<RequireAuth><Profile /></RequireAuth>} />
            <Route path="/rankings" element={<RequireAuth><Rankings /></RequireAuth>} />
            <Route path="/my-rankings" element={<RequireAuth><MyRankings /></RequireAuth>} />
            <Route path="/users/:id" element={<UserProfile />} />
            <Route path="/notifications" element={<RequireAuth><Notifications /></RequireAuth>} />
            <Route path="/admin" element={<RequireAdmin><AdminShell /></RequireAdmin>}>
              <Route index element={<AdminDashboard />} />
              <Route path="tournaments/new" element={<TournamentWizard />} />
              <Route path="tournaments/:id" element={<AdminTournament />} />
              <Route path="tournaments/:id/builder" element={<AdminBuilder />} />
              <Route path="tournaments/:id/import" element={<AdminImport />} />
              <Route path="tournaments/:id/results" element={<AdminResults />} />
              <Route path="tournaments/:id/ingestion" element={<AdminIngestion />} />
              <Route path="tournaments/:id/scoring" element={<AdminScoring />} />
              <Route path="tournaments/:id/analytics" element={<AdminAnalytics />} />
              <Route path="audit" element={<AdminAudit />} />
              <Route path="rankings" element={<AdminRankings />} />
            </Route>
            <Route path="*" element={<NotFound />} />
          </Route>
        </Routes>
      </Suspense>
    </BrowserRouter>
  )
}
