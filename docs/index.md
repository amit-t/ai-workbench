---
title: Home
layout: landing
description: A per-bundle private AI harness for dev and QA collaboration. Jira epics to PRDs, specs, BDDs, test cases, and ralph fix_plans across multiple code repos.
---

<header class="container hero">
  <div>
    <span class="hero-eyebrow">AMIT TIWARI · Dev + QA</span>
    <h1>One harness. Two collaborators. Every artifact gated.</h1>
    <p class="hero-desc">
      <code>ai-workbench</code> is a private git template stamped per Jira epic bundle. Dev and QA share it to draft
      PRDs, engineering specs, TDDs, BDDs, test cases, and test specs, then let <strong>ralph</strong> plan and
      execute across multiple service and automation repos.
    </p>
    <div class="hero-actions">
      <a class="neo-btn neo-btn-primary" href="https://github.com/amit-t/ai-workbench" target="_blank" rel="noreferrer">Open Repo</a>
      <a class="neo-btn neo-btn-accent" href="{{ '/getting-started.html' | relative_url }}">Getting started</a>
      <a class="neo-btn" href="{{ '/architecture.html' | relative_url }}">Architecture</a>
    </div>
    <div class="badge-row">
      <span class="badge badge-blue">Devin</span>
      <span class="badge badge-green">Claude</span>
      <span class="badge badge-purple">Codex</span>
      <span class="badge badge-orange">ai-ralph</span>
      <span class="badge badge-cyan">Jira + Figma MCP</span>
    </div>
  </div>

  <div class="hero-stats">
    <div class="stat-card">
      <span class="stat-value">18</span>
      <span class="stat-label">Bundled skills</span>
    </div>
    <div class="stat-card">
      <span class="stat-value">3</span>
      <span class="stat-label">Lifecycle stages</span>
    </div>
    <div class="stat-card">
      <span class="stat-value">5</span>
      <span class="stat-label">Role hats</span>
    </div>
    <div class="stat-card">
      <span class="stat-value">N</span>
      <span class="stat-label">Code repos orchestrated</span>
    </div>
  </div>
</header>

<hr class="divider container">

<section class="container section" id="lifecycle-section">
  <div class="section-header">
    <div>
      <span class="section-eyebrow eyebrow-lifecycle">Lifecycle</span>
      <h2>draft → published → approved</h2>
    </div>
    <a class="section-link" href="{{ '/lifecycle.html' | relative_url }}">Read the full flow</a>
  </div>

  <div class="flow-box">
    <div class="flow-step"><span class="step-num">01</span>draft</div>
    <div class="flow-step"><span class="step-num">02</span><code>wb.publish</code></div>
    <div class="flow-step"><span class="step-num">03</span>published</div>
    <div class="flow-step"><span class="step-num">04</span><code>wb.approve</code></div>
    <div class="flow-step"><span class="step-num">05</span>approved</div>
    <div class="flow-step"><span class="step-num">06</span>ralph consumes</div>
  </div>

  <p style="margin-top: 1.25rem; font-size: 0.9rem; color: var(--muted-light)">
    Agents only ever write <code>draft</code>. Humans transition via <code>wb.publish</code>, <code>wb.approve</code>,
    <code>wb.reject</code>. Ralph is gated on <code>.workbench-state/approved.json</code>.
  </p>
</section>

<hr class="divider container">

<section class="container section" id="what-section">
  <div class="section-header">
    <div>
      <span class="section-eyebrow eyebrow-readme">What it gives you</span>
      <h2>One repo for the whole epic bundle</h2>
    </div>
  </div>

  <div class="card-grid">
    <div class="card">
      <span class="section-eyebrow eyebrow-pm">PO</span>
      <h3 style="margin-top: 0.5rem">Jira to PRD</h3>
      <p style="color: var(--muted-light); font-size: 0.9rem">
        Pull epic bodies with <code>/epic-intake</code>, draft PRDs with <code>/prd-draft</code>, gate via
        <code>wb.publish</code> and <code>wb.approve</code>.
      </p>
    </div>
    <div class="card">
      <span class="section-eyebrow eyebrow-eng">Dev</span>
      <h3 style="margin-top: 0.5rem">Spec + TDD</h3>
      <p style="color: var(--muted-light); font-size: 0.9rem">
        <code>/eng-spec</code> from an approved PRD. <code>/tdd</code> adds file maps, interfaces, sequence
        diagrams, failure matrix per repo.
      </p>
    </div>
    <div class="card">
      <span class="section-eyebrow eyebrow-agent">QA</span>
      <h3 style="margin-top: 0.5rem">BDD to test spec</h3>
      <p style="color: var(--muted-light); font-size: 0.9rem">
        <code>/bdd-gen</code>, <code>/test-cases-gen</code>, <code>/test-spec</code>. Gherkin, then cases with
        priority, automation flags, and coverage matrix.
      </p>
    </div>
    <div class="card">
      <span class="section-eyebrow eyebrow-ralph">Ralph</span>
      <h3 style="margin-top: 0.5rem">Multi-repo dispatch</h3>
      <p style="color: var(--muted-light); font-size: 0.9rem">
        <code>/ralph-workspace-plan</code> scans <code>repos/*</code> and writes per-repo fix_plans.
        <code>/ralph-dispatch</code> runs them in parallel.
      </p>
    </div>
    <div class="card">
      <span class="section-eyebrow eyebrow-ux">UX</span>
      <h3 style="margin-top: 0.5rem">Figma + screens</h3>
      <p style="color: var(--muted-light); font-size: 0.9rem">
        <code>/figma-pull</code>, <code>/ds-screen-gen</code>, <code>/design-draft</code>,
        <code>/design-review</code>. Handoff context alongside PRDs and specs.
      </p>
    </div>
    <div class="card">
      <span class="section-eyebrow eyebrow-proj">Template</span>
      <h3 style="margin-top: 0.5rem">One-way updates</h3>
      <p style="color: var(--muted-light); font-size: 0.9rem">
        <code>update.wb</code> pulls template improvements from <code>ai-workbench</code> without touching
        user-owned artifacts.
      </p>
    </div>
  </div>
</section>

<hr class="divider container">

<section class="container section" id="two-repos">
  <div class="section-header">
    <div>
      <span class="section-eyebrow eyebrow-arch">Architecture</span>
      <h2>Two repos, one story</h2>
    </div>
    <a class="section-link" href="{{ '/architecture.html' | relative_url }}">Architecture deep dive</a>
  </div>

  <div class="card-grid">
    <a class="card-link" href="https://github.com/amit-t/ai-workbench" target="_blank" rel="noreferrer">
      <span class="card-link-kicker eyebrow-skills">Template</span>
      <span class="card-link-title">ai-workbench</span>
      <span class="card-link-desc">
        Per-bundle private git template. Ships skills, scripts, lifecycle aliases, config templates.
        <code>gh repo create --template</code> stamps an instance per bundle.
      </span>
    </a>
    <a class="card-link" href="https://github.com/amit-t/ai-devkit" target="_blank" rel="noreferrer">
      <span class="card-link-kicker eyebrow-pm">Global CLI</span>
      <span class="card-link-title">ai-devkit</span>
      <span class="card-link-desc">
        Global launchers — <code>init.wb</code>, <code>join.wb</code>, <code>update.wb</code>. One-command per
        machine. Forces Devin by default, <code>.cly</code> variant forces Claude.
      </span>
    </a>
  </div>
</section>

<hr class="divider container">

<section class="container section" id="quick-paths">
  <div class="section-header">
    <div>
      <span class="section-eyebrow eyebrow-start">Quick paths</span>
      <h2>Where do you want to start?</h2>
    </div>
  </div>

  <div class="card-grid">
    <a class="card-link" href="{{ '/getting-started.html' | relative_url }}">
      <span class="card-link-kicker eyebrow-start">Start here</span>
      <span class="card-link-title">Getting started</span>
      <span class="card-link-desc">Install the devkit, stamp your first workbench, share with a teammate.</span>
    </a>
    <a class="card-link" href="{{ '/architecture.html' | relative_url }}">
      <span class="card-link-kicker eyebrow-arch">Architecture</span>
      <span class="card-link-title">Architecture</span>
      <span class="card-link-desc">Two-repo shape, directory tree, manifest policy, ralph adapter contract.</span>
    </a>
    <a class="card-link" href="{{ '/lifecycle.html' | relative_url }}">
      <span class="card-link-kicker eyebrow-lifecycle">Lifecycle</span>
      <span class="card-link-title">Artifact lifecycle</span>
      <span class="card-link-desc">draft → published → approved. Commands, rules, and rejection handling.</span>
    </a>
    <a class="card-link" href="{{ '/skills.html' | relative_url }}">
      <span class="card-link-kicker eyebrow-skills">Skills</span>
      <span class="card-link-title">Skills reference</span>
      <span class="card-link-desc">All 18 skills. Slash commands grouped by role — PO, dev, QA, UX, agent ops.</span>
    </a>
    <a class="card-link" href="{{ '/ralph.html' | relative_url }}">
      <span class="card-link-kicker eyebrow-ralph">Ralph</span>
      <span class="card-link-title">Ralph integration</span>
      <span class="card-link-desc">Workspace-mode planning, context routing, parallel dispatch.</span>
    </a>
    <a class="card-link" href="{{ '/faq.html' | relative_url }}">
      <span class="card-link-kicker eyebrow-faq">FAQ</span>
      <span class="card-link-title">FAQ</span>
      <span class="card-link-desc">Per-bundle vs permanent hub, Devin vs Claude, conflicts, secrets, upstream PRs.</span>
    </a>
  </div>
</section>

<hr class="divider container">

<section class="container section" id="typical-flow">
  <div class="section-header">
    <div>
      <span class="section-eyebrow eyebrow-ai">Typical flow</span>
      <h2>From a Jira epic to parallel ralph dispatch</h2>
    </div>
  </div>

<pre><code>Jira epic → /epic-intake    → publish + approve
         → /prd-draft       → publish + approve
         → /eng-spec        → publish + approve   (dev hat)
         → /tdd             → publish + approve
         → /bdd-gen         → publish + approve   (QA hat)
         → /test-cases-gen  → publish + approve
         → /test-spec       → publish + approve
         → /ralph-workspace-plan       # per-repo fix_plans
         → /ralph-dispatch             # parallel autonomous execution
</code></pre>
</section>
