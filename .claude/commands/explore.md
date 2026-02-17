# /explore - Structured Exploration Before Building

Lightweight exploration to understand a problem before committing to a solution.
Use when starting inception tasks, investigating unknowns, or evaluating approaches.

## Prerequisites

1. Verify an active task exists (`cat .context/working/focus.yaml`)
2. If no task: `fw work-on "description" --type inception` first

## Workflow

### Step 1: Frame the Problem
State the problem or question in **one sentence**. Print it clearly.

### Step 2: Identify Key Questions
List **3-5 questions** that need answers before you can proceed. Number them.
Present to user: "These are the questions I need to answer. Anything to add or change?"

**Wait for user response before proceeding.**

### Step 3: Research Each Question
For each question:
1. Research it (codebase search, web search, doc lookup — whatever fits)
2. Write a **one-paragraph finding** with source references

Keep research concise. Target: 5-10 minutes total, not 60.

### Step 4: Present Options
Based on findings, present **numbered options** for how to proceed.
Include trade-offs for each option (1-2 sentences).

**Wait for user to choose before doing anything else.**

## Rules

- This skill does ONE thing: explore. It does not chain to planning or building.
- No artifacts are written to disk — findings stay in conversation.
- No commits during exploration — this is research, not work.
- If exploration reveals the problem is bigger than expected, say so and suggest task decomposition.
- Target total time: 5-10 minutes. If you're going longer, you're over-exploring.
- Present findings as numbered lists, not prose walls.
