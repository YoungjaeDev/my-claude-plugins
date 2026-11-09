# Deploy Doc Patterns

The standard skeleton, a filled example, and anti-patterns for client-facing
deployment / procedure documents (`.md`). The `## Deploy-doc` section's `### Quick
Reference` in the `doc-guides` skill is the SSOT; this document concretizes that
skeleton. The skeleton and example below are shown in the Korean-default output
form the tool generates (use `--lang en` for English labels).

## Skeleton

````markdown
# <문서 제목 (--title)>

<제품/서비스 X를 대상 환경에 배포하는 절차입니다. 전제조건을 모두 충족한 뒤 아래 N단계를
순서대로 진행하세요. 상세 계약은 링크된 SSOT 문서를 따릅니다.>

## 전제조건

- [ ] <충족해야 할 항목 1>
- [ ] <충족해야 할 항목 2>
- [ ] <충족해야 할 항목 3>

## 절차

### 1. <첫 단계 제목>

<할 일 한 문장. 세부 계약은 [SSOT 문서](path/to/spec.md)로 링크.>

```bash
<명령>
```

기대 결과: <성공했을 때 보이는 출력이나 화면>

### N. <마지막 단계 제목>

<할 일 한 문장.>

```bash
<명령>
```

기대 결과: <성공했을 때 보이는 출력이나 화면>
````

- The document title is `# H1` (`--title`); directly below it, place an **untitled summary paragraph** (2-3 lines, no section heading of its own) above the first `##`. If there is no title, the summary is the very top of the file. The step count named in the summary must equal the number of `### N.` headings.
- Every line under `## 전제조건` is a `- [ ]` item.
- Every step under `## 절차` is a contiguously numbered `### N.` heading with at least 3 body lines: the action, the command or screen, and the expected result.
- Tone follows `writing-standard.md`: checklist items end in a noun or 개조식 `~음`/`~함`, and full sentences use 합니다체 (`~하세요` for an action, `~합니다` for the summary), never 한다체.

## Filled example

````markdown
# 추론 서비스 배포

추론 서비스를 클라이언트 GPU 장비에 배포하는 절차입니다. 전제조건 체크리스트를 모두
충족한 뒤 아래 3단계(이미지 전달, 컨테이너 기동, 헬스체크)를 순서대로 진행하세요.
모델 가중치 경로와 포트 매핑 계약은 배포 명세 문서를 따릅니다.

## 전제조건

- [ ] 대상 장비에 NVIDIA 드라이버 및 컨테이너 런타임 설치 확인
- [ ] 배포용 레지스트리 접근 토큰 발급
- [ ] 모델 가중치를 공유 스토리지에 업로드함

## 절차

### 1. 이미지 전달

레지스트리에서 추론 이미지를 대상 장비로 받으세요. 태그와 다이제스트는
[배포 명세](deploy/spec.md)의 이미지 계약을 따릅니다.

```bash
docker pull <registry>/inference@<digest>
```

기대 결과: `Status: Downloaded newer image` 또는 `Image is up to date`

### 2. 컨테이너 기동

명세의 포트 매핑과 환경 변수로 컨테이너를 기동하세요. 포트·볼륨 계약은
[배포 명세](deploy/spec.md)에만 있고 이 문서에서 다시 정의하지 않습니다.

```bash
docker run -d --gpus all --env-file inference.env <명세의 포트·볼륨 옵션> <registry>/inference@<digest>
```

기대 결과: `docker ps` 에 컨테이너가 `Up` 으로 표시됨

### 3. 헬스체크

`/healthz` 응답과 샘플 추론 1건을 확인하세요.

```bash
curl -fsS http://<host>:<port>/healthz
```

기대 결과: HTTP 200. 실패하면 1단계 이미지 다이제스트 일치 여부부터 확인하세요.
````

> Only the structure is modeled on a reference deploy doc (`pcb-goldfinger-chamfer`); the content is a generic example.

## Anti-patterns

- **Inlining the SSOT** — copy-pasting contracts such as port tables, schemas, or weight paths into the procedure body. The moment the spec changes, the doc becomes false. Delegate to a link instead.
- **Prose steps without `### N.`** — a paragraph-style procedure ("first do X, then do Y"). Decompose it into numbered headings so it is traceable and verifiable.
- **Summary/body count mismatch** — the summary says "3 steps" but there are 4 `### N.` headings. The first signal that makes a reader lose trust; the number-match rule blocks it.
