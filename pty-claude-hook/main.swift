//
//  main.swift
//  pty-claude-hook
//
//  Created by KUN-MAC-MINI on 1/12/26.
//

import Foundation

// stdin 기반 훅 이벤트 처리만 수행하는 CLI 엔트리포인트
SettingsStore.registerDefaults()
HookRunner.run()
