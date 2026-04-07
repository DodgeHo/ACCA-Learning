# ACCA Subjective-First Overhaul Plan

## Goal
Make the app truly usable for ACCA subjects where essay and case questions dominate, while keeping the existing database schema unchanged.

## Current Gap
- Data pipeline is still optimized for objective questions.
- Subjective prompts are shown as plain text, with limited structure and no mark-based workflow.
- No explicit workflow for: requirement decomposition, key-point checklist, and self-marking against scheme.

## Phase 1: Data Pipeline Hardening (1-2 weeks)
1. Keep schema unchanged; standardize fields by convention:
- `stem_zh`: full question and requirements.
- `explanation_zh`: marking points / sample answer / examiner notes.
- `source_doc`: encode metadata such as `ACCA:<subject>:<type>:<file>#<block>`.
- `options_zh`: only for true objective blocks.

2. Introduce OCR quality tags in manifest only (not DB schema):
- confidence bucket per block (high/medium/low)
- parser warnings (missing requirement marker, missing answer marker)

3. Build deterministic validation scripts:
- minimum stem length threshold
- duplicate block detection (hash)
- question type distribution checks per subject

## Phase 2: Subjective UX Upgrade (2-4 weeks)
1. Question workspace redesign:
- left: question + requirement splitter
- right: answer checklist + marking scheme snippets
- bottom: personal draft notes (local only)

2. New study actions (mapped to existing status values):
- `Know`: can independently produce answer framework
- `DontKnow`: cannot produce framework in time
- `Favorite`: high-value or repeatedly wrong scenario

3. AI prompts by type:
- objective: option elimination + trap analysis
- case: step-by-step framework + risk identification
- essay: structure-first answer plan (intro, points, conclusion)

## Phase 3: Marking and Review Loop (2-3 weeks)
1. Timed practice mode:
- countdown by marks and question type
- autosave user draft in local history

2. Self-mark mode:
- checklist scoring against extracted marking points
- gap summary: missed technical points, weak justification, structure issues

3. Spaced repetition for subjective blocks:
- schedule by topic + previous self-mark score
- prioritize weak requirements instead of full long case each time

## Phase 4: Release and Variants (1 week)
1. Keep one-command per-subject build for Android/Windows/Web.
2. Produce release notes with parser quality metrics per subject.
3. Regression checks:
- app startup with each bank
- question count not zero
- random sample render for objective/case/essay

## Immediate Next Actions
1. Use OCR DOCX bank builder to regenerate each subject bank.
2. Run smoke checks on PM (objective-heavy) and SBL (essay-heavy).
3. Collect false-split examples and refine parsing rules iteratively.
