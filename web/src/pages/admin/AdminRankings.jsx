import React from 'react'
import { api } from '../../lib/api'
import RankingsEditor from '../../components/rankings/RankingsEditor'

export default function AdminRankings() {
  return (
    <RankingsEditor
      queryKeyPrefix="admin-rankings"
      getRankings={api.adminRankings}
      getPool={api.adminRankingsPool}
      saveRankings={api.saveAdminRankings}
      title="Composite Rankings"
      subtitle="Manually managed per weight class — drag to reorder, search the roster to add someone, remove anyone who shouldn't be ranked."
    />
  )
}
