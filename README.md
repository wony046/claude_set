# claude_set

Claude Code 개인 설정을 여러 컴퓨터에서 동일하게 유지하기 위한 저장소.
`home/` 의 내용을 각 컴퓨터의 `~/.claude/` 로 복사해서 쓴다.

## 구조

```
home/                     ~/.claude/ 로 복사되는 정본
├── CLAUDE.md             모든 프로젝트에 적용되는 공통 규칙
├── settings.json         공유하는 설정 항목만 (나머지는 각 컴퓨터가 관리)
└── output-styles/        출력 스타일
bootstrap/
├── sync-claude.sh        우분투·맥
└── sync-claude.ps1       윈도우 (미검증)
```

## 새 우분투 컴퓨터에서

```bash
git clone https://github.com/wony046/claude_set.git ~/claude_set
~/claude_set/bootstrap/sync-claude.sh
```

## 사용법

```bash
sync-claude.sh            home/ 을 ~/.claude/ 로 설치하고 공유 설정을 병합
sync-claude.sh --status   양쪽을 비교만 함
sync-claude.sh --pull     ~/.claude/ 에서 고친 것을 home/ 으로 회수
```

## 규칙을 고칠 때

1. `home/` 안의 파일을 고친다
2. `bootstrap/sync-claude.sh` 로 이 컴퓨터에 반영한다
3. 커밋하고 푸시한다
4. 다른 컴퓨터에서 `git pull` 후 스크립트를 실행한다

`CLAUDE.md` 와 출력 스타일은 다음 세션부터 반영된다.

## 참고

- `settings.json` 은 통째로 덮어쓰지 않고 적힌 항목만 복사해서 추가로 넣음.
  모델과 노력 수준 등은 각 컴퓨터에서 vscode UI 로 조정하는 값이라 여기 넣지 않음.
- `claudeMdExcludes` 는 이 저장소 안의 `CLAUDE.md` 가 프로젝트 규칙으로
  한 번 더 읽히는 것을 막음.
