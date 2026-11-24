# StudyMate — a local tutor chatbot for students

A small, self-hosted study assistant. Students sign in, ask questions, upload their
class notes, and get explanations at their own level and in their own language.
It runs on one laptop with a small local model, and the same code is built to grow
into a multi-student deployment later.

- **Local first.** Default model is `qwen2.5:3b` through [Ollama](https://ollama.com) — no API bill, works offline.
- **Tuned for students.** Six teaching modes (explain, step-by-step, exam, socratic, revision notes, doubt solver), class level, and 12 reply languages including Hindi and Hinglish.
- **Uses your notes.** Upload a chapter PDF; the tutor quotes it before answering and shows the source under the reply.
- **Quizzes.** Generates MCQs from a topic or from your notes, marks them, explains each answer.
- **Multi-student ready.** Accounts, per-student chat history, per-student isolation, teacher accounts that share notes with the class, per-user rate limits.

Everything is plain Python + FastAPI + SQLite + one HTML page. No build step, no Node, no Docker needed to start.

---

## 1. Run it on your laptop

**Step 1 — install Ollama and a small model** (one time):

```bash
# macOS / Linux
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5:3b        # ~2 GB download
```

On Windows, install Ollama from ollama.com, then run `ollama pull qwen2.5:3b` in PowerShell.
Ollama keeps running in the background; `ollama serve` starts it manually if needed.

**Step 2 — start the app:**

```bash
# Linux / macOS
bash run.sh

# Windows - double-click run.bat, or in PowerShell:
.\run.bat

# Windows inside Git Bash or WSL
bash run.sh
```

Or by hand:

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

**Step 3 — open http://127.0.0.1:8000**, create an account, ask a question.

If the top bar shows a yellow warning, it names the exact fix (model not pulled, Ollama
not running, missing API key). You can also click around in demo mode without a model:
set `LLM_PROVIDER=stub` in `.env`.

### Which model should I use?

| Laptop RAM | Model (`OLLAMA_MODEL=`) | Feel |
|---|---|---|
| 8 GB | `qwen2.5:1.5b` | fast, weaker reasoning |
| 8–16 GB | `qwen2.5:3b` (default) | good balance for Class 6–12 |
| 16 GB | `qwen2.5:7b` or `llama3.1:8b` | noticeably better explanations |
| 24 GB+ GPU | `qwen2.5:14b` | close to cloud quality |

Start with the default. If answers are vague, move one step up the table — model size
matters far more than prompt tweaking.

### Using a cloud model instead

Any OpenAI-compatible endpoint works (OpenAI, Groq, Sarvam, Together, vLLM, LM Studio):

```env
LLM_PROVIDER=openai
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_API_KEY=sk-...            # keep this in .env only, never in code
OPENAI_MODEL=gpt-4o-mini
```

For a school, this is usually the better choice: the laptop does not need to be on, and
responses are faster. Costs are per token, so keep `RATE_LIMIT_PER_MIN` in place.

---

## 2. Put it on phones

**The one rule:** the model stays on the server. A phone cannot run `qwen2.5:3b`
usefully — it needs ~2 GB of RAM and a laptop-class CPU. The phone is a thin client that
talks to your laptop, a school PC, or a cloud box. Every option below assumes that.

### Option A — install it as an app (PWA), no store, no build tools

This is the fastest route and it is already built in: `app/static/manifest.webmanifest`,
a service worker (`app/static/sw.js`) that caches the shell, and icons.

1. Start the server so other devices can reach it:
   ```bash
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
2. Find the laptop's LAN address (`ipconfig` on Windows, `ifconfig`/`ip addr` on
   Linux/macOS) — say `192.168.1.20`.
3. On the phone, same Wi-Fi, open `http://192.168.1.20:8000`.
4. **Android (Chrome):** menu ⋮ → "Add to Home screen" / "Install app".
   **iPhone (Safari):** Share → "Add to Home Screen".

It then opens full screen with its own icon, no browser bar.

Two caveats worth knowing:

- **Offline caching and the install prompt need HTTPS** (or `localhost`). Over plain
  `http://192.168.x.x` the app still installs and works, but the service worker is
  skipped, so it will not open without a connection. To get HTTPS quickly: put it behind
  [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
  (`cloudflared tunnel --url http://localhost:8000`), Caddy with a real domain, or deploy
  the container to Render/Railway/Fly.
- **The laptop must stay awake** while students use it. For a class, put the server on a
  machine that stays on, or use a cloud provider for the model instead
  (`LLM_PROVIDER=openai`).

### Option B — a real Android APK (Capacitor)

When you need a file you can share, sideload, or put on Play Store:

```bash
npm init -y
npm i @capacitor/core @capacitor/cli @capacitor/android
npx cap init StudyMate in.school.studymate --web-dir=app/static
npx cap add android
npx cap sync
npx cap open android      # opens Android Studio, then Build > Build APK
```

Two ways to connect the wrapper to your server:

- **Point at the hosted site** (simplest): in `capacitor.config.json` add
  `"server": { "url": "https://tutor.school.in", "cleartext": false }`. The APK is just a
  shell around the live site — every update is instant, no new APK.
- **Bundle the UI, call the API remotely:** leave the web assets in the APK, set
  `<meta name="api-base" content="https://tutor.school.in">` in
  `app/static/index.html`, and add the wrapper's origin to `ALLOWED_ORIGINS` in `.env`:
  ```env
  ALLOWED_ORIGINS=https://localhost,capacitor://localhost
  ```
  (`https://localhost` is what Capacitor serves the bundled files from on Android.)

Rebuild the APK only when the UI changes, not for every content change.

### Option C — embed it inside an app or site you already have

- **iframe:** `<iframe src="https://tutor.school.in" style="width:100%;height:100%;border:0"></iframe>`
- **WebView (Android):** load the same URL in a `WebView` with JavaScript enabled.
- Either way, add the embedding origin to `ALLOWED_ORIGINS`, otherwise the browser blocks
  the API calls.

### Option D — pushing it to a whole class automatically

There is no "auto-install on every phone" that works without the phone owner's consent —
Android and iOS both require the user to accept an install. What schools actually do:

- **Managed devices (MDM):** if the school owns the tablets, an MDM (Google
  Endpoint Management, Hexnode, Scalefusion) can push the APK or a home-screen shortcut
  to every device silently.
- **Shared tablets:** install once per device via Option A, then let students log in with
  their own accounts — chats and progress stay separate per account.
- **Everyone else:** share a link and the "Add to Home screen" step; it takes 10 seconds
  per student.


## 3. Tuning it for your students

Almost all behaviour lives in **`app/tutor.py`** — edit text, restart, done.

| What to change | Where |
|---|---|
| Tone, rules, "never do homework for them", source-citation rules | `BASE_RULES` in `app/tutor.py` |
| Teaching modes and their instructions | `MODES` in `app/tutor.py` |
| Assistant name | `TUTOR_NAME` in `.env` |
| Reply languages | `LANGUAGES` in `app/tutor.py` |
| Grade / board wording | `build_system_prompt()` in `app/tutor.py` |

The system prompt is deliberately short and concrete: small local models follow 10 clear
rules better than 40 vague ones. Change one rule at a time and check a real question.

Two prompt decisions worth knowing:

- **The student's level is sent on every turn** (`Class 10`, language), because a 3B model will not remember it from the UI.
- **Uploaded notes are pasted into the prompt, not trusted blindly.** The prompt tells the model the notes win over general knowledge, and to cite `[Source: title]`.

---

## 4. Class notes (how retrieval works)

1. A teacher (or student) uploads a `.pdf`, `.txt`, `.md` or `.docx`.
2. Text is extracted and split into ~900-character chunks (`app/rag.py:chunk_text`).
3. On each question, a small BM25 index ranks the chunks and the best 4 go into the prompt.
4. The reply shows the source titles underneath.

BM25 is keyword-based, so it is instant and needs no extra model, but it misses synonyms
("heart attack" vs "myocardial infarction"). When that matters:

- **Upgrade retrieval**: replace `rag.retrieve()` with embeddings — Ollama serves
  `nomic-embed-text` locally, so you can embed chunks at upload time and store vectors in
  SQLite (`sqlite-vec`) or `pgvector`. The rest of the app does not change; keep the same
  `{title, text, score}` return shape.
- **Fix the input first**: one chapter per file, with the chapter name in the filename,
  gives a bigger jump than any retrieval upgrade.

Uploads are capped at `MAX_UPLOAD_MB` (15 MB). Scanned PDFs are rejected with a clear
message — run OCR first, then upload.

---

## 5. What is in the box

```
student-tutor/
├── app/
│   ├── main.py        FastAPI routes: auth, chats (SSE streaming), materials, quizzes
│   ├── config.py      every setting, from .env
│   ├── db.py          SQLite schema + connection helper
│   ├── auth.py        scrypt passwords, bearer sessions, role checks
│   ├── llm.py         ollama / openai / stub backends, one streaming interface
│   ├── tutor.py       ← the student-specific part: prompts and modes
│   ├── rag.py         chunking + BM25 search over class notes
│   ├── quizzes.py     file-to-text extraction and MCQ generation
│   └── static/        index.html, styles.css, app.js (no build step)
│                      manifest.webmanifest, sw.js, icons (installable app)
├── tests/             pytest end-to-end checks over the real routes
├── requirements.txt   five packages
├── .env.example       copy to .env
├── run.sh / run.bat   one-command start
└── Dockerfile         optional
```

### API (all JSON, `Authorization: Bearer <token>`)

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/signup`, `/api/login` | get a token |
| GET/PATCH | `/api/me` | profile: class, language |
| GET/POST | `/api/chats` | list / create a chat |
| GET/PATCH/DELETE | `/api/chats/{id}` | open, retitle, delete |
| POST | `/api/chats/{id}/message` | ask a question (SSE stream) |
| GET | `/api/chats/{id}/export` | chat as Markdown |
| POST/GET | `/api/materials` | upload / list class notes |
| GET | `/api/materials/search?q=` | preview what the tutor would retrieve |
| POST/GET | `/api/quizzes` | generate / list quizzes |
| POST | `/api/quizzes/{id}/attempt` | submit answers, get score |
| GET | `/api/health` | model status, version, build stamp |

Interactive docs: http://127.0.0.1:8000/docs

---

## 6. Tests

```bash
pip install pytest
python -m pytest tests -q
```

Seven tests run against the real HTTP routes with `LLM_PROVIDER=stub`: signup/login,
401 guards, streaming chat persistence, upload + retrieval + source attachment, quiz
generation and scoring, export, and one student being unable to read another's chat.

---

## 7. From one laptop to a whole school

The code already separates the parts that need to scale. In order of what actually
breaks first:

1. **SQLite → Postgres.** All SQL is in `app/db.py`. Swap `sqlite3` for `psycopg` and the
   `?` placeholders for `%s`; the schema is already normalised. Do this before ~50
   concurrent students.
2. **One worker → many.** `uvicorn app.main:app --workers 4` behind nginx/Caddy. Then move
   the in-memory rate limiter (`main.py:check_rate`) to Redis so limits are shared.
3. **Model serving.** Ollama serves one request at a time per model. For a class of 30,
   run a GPU box with vLLM (OpenAI-compatible) and point `OPENAI_BASE_URL` at it.
   One 16 GB GPU comfortably handles ~20–40 concurrent students on a 7B model.
4. **Accounts.** Add email verification, password reset, and Google/Classroom sign-in.
   Add a `class_id` column to `users` if you want per-class isolation rather than
   per-teacher shared notes.
5. **Safety.** For a real school deployment: log every model call, add a content filter on
   both directions, keep the "don't do graded homework" rule, and put a teacher-visible
   dashboard on top of `messages`.
6. **Backups.** The whole app is `data/tutor.db`. Copy it nightly (`sqlite3 .backup`), and
   keep uploaded originals if you ever need to re-index.

What it is not yet: password reset, email verification, file storage outside the DB
(text is stored in SQLite — fine to ~1 GB of notes), streaming voice, and a teacher
dashboard. All are additive; none require restructuring.

---

## 8. Privacy

Chats, notes and accounts stay in `data/tutor.db` on the machine you run. With
`LLM_PROVIDER=ollama`, nothing leaves that machine. With a cloud provider, the question,
the recent chat turns and any retrieved note chunks are sent to that provider — tell
students this, and avoid uploading personal documents as "class notes".
