---
title: 프로젝트 시작 상담 신청
options:
  - 꼭 필요해요
  - 있으면 좋아요
  - 필요 없어요
theme: neutral
---

# 프로젝트 시작 상담 신청

> 프로젝트를 함께 그려보기 전에 몇 가지만 여쭤볼게요.
>
> 3분이면 충분하고, 적어주신 내용은 첫 미팅 준비에만 씁니다.

### 연락처
%%text  label: 이름 (required) (placeholder: 홍길동)
%%email label: 이메일 (required) (placeholder: name@example.com)
%%phone label: 연락 가능한 번호 (desc: 통화가 어려우면 비워두셔도 돼요)
%%link  label: 참고할 사이트나 포트폴리오 (desc: 있으면 링크를 붙여주세요)

## 원하는 기능
- [ ] 로그인 (예: 이메일·카카오 로그인)
- [ ] 결제 (예: 카드·간편결제)
- [ ] 검색·필터

%%choice
title: 주로 어떤 작업이 필요하세요
options: 브랜딩, 웹사이트, 모바일 앱, 마케팅, 기타
select: multi
required: true
desc: 해당되는 항목을 모두 골라주세요
%%

### 일정·예산
- 희망 일정: ___
- 예산 범위: ___

## 동의
%%choice
title: 개인정보 수집·이용 동의
options: 동의합니다
select: single
required: true
desc: 상담 연락을 위해 이름·연락처를 수집하며, 상담이 끝나면 파기합니다
%%
