# Build runbook — the manual (console) steps

CloudFormation handles the Knowledge Base, S3 Vectors wiring, data source,
guardrail, and the fulfillment Lambda. Three things must be done by hand
because they have no usable CloudFormation path yet:

1. the S3 Vectors bucket + index (a script does this — step 0),
2. **the Lex bot + QnAIntent** (not CFN-native — this runbook),
3. the Lex Web UI (deploy AWS's prebuilt template).

Build bottom-up. Each layer must fully exist before the next references it.

---

## Order of operations

```
[0] scripts/00-bootstrap-vectors.sh   -> vector bucket + index (note the ARNs)
[1] Bedrock console: enable model access (Titan V2 + Claude)   <-- MANUAL, below
[2] scripts/01-deploy.sh <arns>       -> stack + upload docs + start ingestion
[3] Bedrock console: confirm the KB answers (test panel)       <-- MANUAL, below
[4] Lex console: bot + QnAIntent + fulfillment + alias         <-- MANUAL, below
[5] Deploy Lex Web UI, point the site widget at it             <-- MANUAL, below
```

---

## [1] Enable Bedrock model access  (before step 2)

Bedrock console → **Model access** → enable:
- **Titan Text Embeddings V2** (the KB embedder — 1024-dim, matches the index)
- **Claude 3.5 Sonnet** (or your chosen answer model)

Miss this and ingestion or the QnAIntent fails silently later.

---

## [3] Confirm the KB works  (before touching Lex)

Bedrock console → Knowledge bases → **meridian-support-kb** → Data source →
confirm the ingestion job from step 2 shows **COMPLETE**. Then use the
built-in **Test** panel: ask *"How much is the security deposit?"* — you
should get a grounded answer with a citation. **Debug RAG here, not through
Lex.** If answers are empty, the sync didn't finish or model access is off.

---

## [4] Lex bot + QnAIntent  (the part CFN can't do)

1. **Lex V2 console → Create bot** → *Traditional* → name `meridian-support`.
   Add an IAM role (basic), no COPPA. Add language **English (US)**.
   Then add a second language **Arabic (Saudi Arabia) `ar_AE`/`ar_SA`** so
   the bot accepts Arabic input directly.
2. Open the bot → the **en_US** locale → **Intents → Add intent → Use
   built-in intent → `AMAZON.QnAIntent`**.
3. In the QnAIntent config:
   - Data source: **Bedrock knowledge base**
   - Knowledge base ID: paste the `KnowledgeBaseId` stack output
   - Model: your answer model
   - If the ARN field shows **`[object Promise]`** — browser glitch. Reload,
     re-enter the KB ID, or switch browsers.
4. **Fulfillment (the bilingual hop).** QnAIntent's native call doesn't run
   Comprehend/Translate. To get AR<->EN translation, attach the stack's
   **`meridian-fulfillment`** Lambda as the bot's fulfillment/codehook so it
   does detect → translate → RetrieveAndGenerate → translate-back:
   - Bot → **Aliases** (after step 5's build) → your alias → Languages →
     for each locale set the **Lambda source** to `meridian-fulfillment`.
   - In the intent, enable **Fulfillment → Use a Lambda function**.
   > Simpler alternative if you don't need Arabic fidelity: skip the Lambda
   > and let native QnAIntent answer; Lex's `ar` locale still accepts Arabic
   > input, but answers come straight from the KB without the Translate
   > round-trip.
5. Repeat the QnAIntent add on the **ar_AE** locale (same KB ID).
6. **Build** the bot (per locale).

---

## [5] Alias + Web UI

1. Bot → **Aliases → Create alias** (e.g. `prod`). Attach the fulfillment
   Lambda per language here. Note the **Bot ID** and **Alias ID**.
2. Deploy the **Lex Web UI**: search `aws-samples/aws-lex-web-ui`, deploy
   their CloudFormation, pass your Bot ID + Alias ID. It gives you a hosted
   widget / iframe snippet.
3. In `site/index.html`, replace the demo `answer()` function with a call to
   the Lex Runtime V2 `RecognizeText` API (or drop in the Web UI iframe).
   The demo already renders the source citation and the short "Anything
   else?" follow-up — keep that UX, just swap the data source.

---

## Adding documents later

**By script:** `./scripts/add-doc.sh path/to/new-policy.pdf` — uploads to the
source bucket and starts a fresh ingestion job.

**By console:** S3 → the `meridian-kb-source-*` bucket → upload the file →
Bedrock → Knowledge bases → meridian-support-kb → Data source → **Sync**.

Either way, new content is answerable once the ingestion job completes. No
redeploy, no Lex change — the KB is the single source of truth.

---

## Teardown

```
aws cloudformation delete-stack --stack-name meridian-chatbot
# then delete the Lex bot, the Web UI stack, and the S3 vector bucket/index
aws s3vectors delete-index  --vector-bucket-name meridian-vectors-<acct> --index-name meridian-kb-index
aws s3vectors delete-vector-bucket --vector-bucket-name meridian-vectors-<acct>
```
