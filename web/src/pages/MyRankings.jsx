import React from 'react'
import { api } from '../lib/api'
import RankingsEditor from '../components/rankings/RankingsEditor'

export default function MyRankings() {
  return (
    <RankingsEditor
      queryKeyPrefix="my-rankings"
      getRankings={api.myRankings}
      getPool={api.myRankingsPool}
      saveRankings={api.saveMyRankings}
      title="My Rankings"
      subtitle="Build your own top-15 per weight class — show everyone your point of view. Public on your profile once you save."
      poolTitle="Add from the roster"
      emptyBody="You haven't ranked anyone at this weight yet — add someone from the roster on the right."
    />
  )
}
