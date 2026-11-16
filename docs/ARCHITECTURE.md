# BudgetApp — how it works today, and a proposed architecture

Status: initial draft, inferred from the code at commit `b44f151`. Nothing in the app was changed.
Part 1 describes current behaviour (the rules). Part 2 proposes a structure.

---

## Part 1 — The app as it is

### 1.1 Overview

iOS 18+, SwiftUI + SwiftData, Swift 6 (strict concurrency), single target, no third-party dependencies. Currency is Colombian pesos, shown as `$ 1.500.000` (`es_CO` grouping, 0–2 decimals).

Three pages live side by side in a custom horizontal pager (`BudgetAppApp`), all alive at once. You move between them with the bottom tab bar, or by swiping on the tab bar or on the 180 pt strip over the navigation title. List rows keep their own gestures.

| Tab | View | Model | Purpose |
|---|---|---|---|
| Transactions | `MonthView` | `Transaction` | Day-to-day log; each entry moves real money (Cash / Savings) |
| Monthly | `MonthlyView` | `FixedExpense` | Checklist of fixed monthly expenses and incomes against a monthly income |
| Expenses ("More expenses") | `ExpensesView` | `NonFixedExpense`, `SubExpense` | Extra expenses/incomes that adjust the Balance |

### 1.2 Stored state

**SwiftData models**

- `Transaction` — `name`, `amount` (always > 0), `kind` (income/expense), `category` (a plain string, not a link), `note`, `date`, `paidWith` (cash / savings / creditCard).
- `FixedExpense` — `name`, `amount` (> 0), `isChecked`, `isIncome`, `category` (optional link to `ExpenseCategory`).
- `NonFixedExpense` — `name`, `amount`, `isIncome`, plus two "special" modes: `isCumulative` (+ `subExpenses`) and `isRecurring` (+ `baseAmount`, `multiplier`).
- `SubExpense` — `value` only.
- `ExpenseCategory` — `name`, `colorHex`.

**Settings (`UserDefaults` via `@AppStorage`, stored as plain-digit strings)**

- `cashBalance`, `savingsBalance` — the two account fields on Transactions.
- `monthlyIncome` — the income field on Monthly.

### 1.3 The big picture: three independent money circuits

```
 Transactions ──create──▶ Cash / Savings fields ─┐
                                                 ├─▶ Balance = Cash + Savings − Σ extra expenses + Σ extra incomes
 Expenses view (NonFixedExpense) ────────────────┘

 Monthly view ──▶ Monthly expenses (checked net) ──▶ Remaining = Monthly income − checked net
        ▲
        └── a Transaction created from a fixed expense checks that row (the only bridge)
```

1. **Real money** — Cash and Savings. Edited by hand, and moved automatically when a transaction is created.
2. **Balance adjustments** — the Expenses view. Its items never touch Cash/Savings; they are subtracted from (expenses) or added to (incomes) the Balance figure. In effect they behave as pending/earmarked amounts on top of the real money. *(My reading of the intent — confirm.)*
3. **Monthly plan** — self-contained. It only produces "Monthly expenses" and "Remaining"; it never touches Cash, Savings or Balance.

### 1.4 Rules — Transactions view

**Summary card (pinned)**

- **Balance** = `Cash + Savings − Σ NonFixedExpense(expense).amount + Σ NonFixedExpense(income).amount`. It is global: it does not change with the displayed month. Red when negative.
- **Income / Expenses pills** = sum of the displayed month's transactions by kind. Informational only; they do not feed the Balance.

**Balance distribution section**

- Cash and Savings are editable; the value is committed when editing ends (blur or Enter), not per keystroke.
- **Available to spend** = Cash + Savings.

**Transaction list**

- Filtered to the displayed month (‹ › to change month, tap the title to return to today), grouped by day, newest first.
- Row: name (falls back to category when empty), category, note, a "paid with" badge for expenses, amount.

**Creating a transaction** (`AddTransactionView`)

- Valid when the name is non-empty and amount > 0.
- Expenses may be created from a fixed expense: picking one prefills name, amount and category (all still editable). On save, that fixed expense becomes **checked** in Monthly, even if the amount was edited.
- Category options: for expenses, `None` + the shared `ExpenseCategory` list; for incomes, a fixed list (Salary, Freelance, Gift, Investment, Other). Switching kind resets the category.
- Effect on the account fields, applied once at save time:

| Kind | Paid with | Effect |
|---|---|---|
| Expense | Cash | Cash − amount |
| Expense | Savings account | Savings − amount |
| Expense | Credit card | none (deferred payment) |
| Income | — | Cash + amount |

**Deleting / editing**

- Swipe to delete removes the row only. By design, the Cash/Savings effect is **not** reverted: deleting removes the record, not the money movement. A fixed expense it checked also stays checked.
- Transactions cannot be edited.

**Backup** (in this tab's ⋯ menu) — see 1.7.

### 1.5 Rules — Monthly view

- **Monthly income** — manually entered (`monthlyIncome`).
- Rows are fixed **expenses** or fixed **incomes** (`isIncome`). The type is chosen when adding and cannot be changed afterwards.
- **Monthly expenses** (displayed) = `Σ checked expenses − Σ checked incomes`.
- **Remaining** = `Monthly income − Monthly expenses`. Green when ≥ 0, red otherwise.
- **Hold** either row to peek at the *estimated* figure, which counts every row regardless of checked state:
  - Estimated monthly expenses = `Σ all expenses − Σ all incomes`
  - Estimated monthly remains = `Monthly income − that`
- Checking a row means "paid / received this month". **Uncheck all** resets every row (the manual start-of-month reset); nothing resets automatically.
- Expenses can have a category: rows are grouped by category, uncategorized last, tinted with the category colour. Uncategorized rows are tinted green when checked. Incomes have no category and are always green.
- Row actions: toggle check, edit (name, amount, category), assign category (context menu), delete.
- Amounts must be > 0, whole numbers (number pad).
- Checking or unchecking here has **no effect** on Cash, Savings or Balance.

**Categories** (`CategoryManagerView`)

- Eight built-in defaults (Housing, Food & Groceries, Transport, Utilities, Health, Entertainment, Education, Savings). They cannot be deleted and are re-created at launch if missing.
- Users can add their own (name + colour from a palette) and delete them. Fixed expenses lose the link; transactions keep the category name as text.

### 1.6 Rules — Expenses view ("More expenses")

Two sections: **Expense**, then **Incomming** (only shown when there are incomes). Within each, special rows come first. Each section footer shows its total.

Three kinds of entry, chosen at creation via the "category" (None / Cumulative / Recurring). Only a name is required.

| Kind | Amount rule | Editing |
|---|---|---|
| Plain | Whatever is typed. May be negative: a negative expense acts as a credit. | Name and amount edited in place; trash button |
| Cumulative (cyan) | `amount = Σ sub-values`. Optional initial sub-value at creation. | Tap opens the sub-value list: add, edit, delete values (non-zero) |
| Recurring (pink) | `amount = baseAmount × multiplier`. Multiplier starts at 1, minimum 1. | − / + stepper on the row; tap opens a modal to edit the base |

- Expense vs income is fixed at creation; special incomes behave exactly like special expenses.
- Every change immediately moves the Balance on the Transactions tab (expenses subtract, incomes add). Cash and Savings are untouched.

### 1.7 Cross-cutting rules

- **Backup** — Export writes one JSON file with every model plus the three settings. Import **replaces everything** after a confirmation. Optional DTO fields keep old backups importable. Standing rule: any new model or field must be added to the backup.
- **SwiftData migrations** — every new `@Model` property needs a default value, or lightweight migration silently fails.
- **Amounts** — stored positive with the sign implied by kind/`isIncome`, except plain entries in the Expenses view, which may be negative.
- **Currency fields** show formatted pesos when idle and raw digits while focused; tapping outside dismisses the keyboard.
- **Seed data** — if there are no fixed expenses (or no extra expenses), a mock list is inserted when the corresponding tab loads.

### 1.8 Things to confirm

These are behaviours I found while reading. They may be intentional; I'm listing them so the documentation and any refactor preserve (or deliberately change) them. None have been touched.

1. **Deleting a transaction does not give the money back** to Cash/Savings. — *Confirmed intentional (2026-11-16); this is a rule, see 1.4.*
2. **Balance is not month-scoped**, although it sits under the month navigator beside month-scoped pills.
3. **Mock data re-seeds whenever a list is empty**, not only on first install — deleting every fixed expense brings the ten mock rows back on next launch. Same for the Expenses view.
4. **The "Fixed expense" picker in New Transaction also lists fixed incomes**, since it shows every `FixedExpense` row.
5. **Balance reads the Expenses-view items with a manual fetch** inside a computed property rather than `@Query`. It works today, but its refresh depends on SwiftUI happening to re-evaluate the view — the most fragile spot in the app.
6. **Sub-values and cumulative entries can be left orphaned** in the store: removing a sub-value, or deleting a cumulative entry from its detail screen, does not delete the `SubExpense` rows (there is no cascade rule). Harmless to totals and ignored by backups.
7. **Monthly rows have both a check toggle and a tap-to-edit gesture** on the same area; which one a tap triggers is worth verifying on device.
8. **Decimal input is parsed inconsistently** — some fields convert `,` to `.`, the New Transaction amount does not, and balance writes use a locale-dependent formatter. Only matters for non-whole amounts.
9. **Naming** — you call day-to-day transactions "NFE", but in code `NonFixedExpense` is the Expenses-view model. Worth settling one vocabulary (see 2.5).

---

## Part 2 — Proposed architecture

### 2.1 The actual problem

The UI is fine. What hurts is that the **rules live inside views**:

- The Balance formula is in `MonthView`; the transaction → Cash/Savings effect is in `AddTransactionView`; the recurring formula is written three times in `ExpensesView`; the cumulative sum lives in `SubExpensesView`.
- The settings keys (`"cashBalance"`, …) are string literals in five files, read and written through three different mechanisms.
- Nothing is unit-testable, so "it works exactly as I want" can only be protected by hand-testing.

So the goal is narrow: **pull the rules out of the views into one small, testable place, and give the settings one owner.** Not a rewrite.

### 2.2 Recommendation: MVVM, the light way

MVVM is a good fit, with one adjustment for SwiftData: **keep `@Query` in the views.** `@Query` only works inside a view, and it is what makes lists update automatically. A "pure" MVVM where view models fetch through `ModelContext` would mean re-implementing that refresh by hand — more code and more bugs for no gain at this size.

Three layers:

```
Views (SwiftUI)          layout, @Query, bindings, navigation
   │  pass data in, call intents
ViewModels (@Observable) screen state + user intents, only where a screen has real logic
   │  delegate every calculation
Domain (plain Swift)     the rules from Part 1 — no SwiftUI, no ModelContext
   │
Data                     SwiftData models (unchanged) · AccountsStore (UserDefaults) · BackupService
```

**Domain** — plain structs and functions, the single home of every formula:

```swift
enum BalanceRules {
    static func balance(cash: Decimal, savings: Decimal, extras: [NonFixedExpense]) -> Decimal
    static func monthSummary(_ transactions: [Transaction], in month: Date) -> (income: Decimal, expenses: Decimal)
    /// Cash/Savings delta for a new transaction (the table in 1.4).
    static func accountEffect(amount: Decimal, kind: TransactionKind, paidWith: PaymentSource) -> AccountDelta
}

struct MonthlyTotals {            // built from [FixedExpense] + monthlyIncome
    let checkedNet, estimatedNet, remaining, estimatedRemaining: Decimal
}

extension NonFixedExpense {       // the two special-mode formulas, written once
    func recalculateCumulative()  // amount = Σ subExpenses
    func setMultiplier(_:)        // amount = baseAmount × multiplier, min 1
    func setBaseAmount(_:)
}
```

**AccountsStore** — one `@Observable` class owning the three `UserDefaults` keys and exposing `cash`, `savings`, `monthlyIncome` as `Decimal`, plus `apply(_ delta:)`. Injected through the environment. It keeps the same keys and string format, so existing data and backups keep working.

**ViewModels** — `@MainActor @Observable` classes, one per screen that has logic:

| ViewModel | Owns |
|---|---|
| `TransactionsViewModel` | displayed month, day grouping, summary, delete, backup export/import state |
| `AddTransactionViewModel` | form state, validation, prefill from a fixed expense, save (insert + account effect + check) |
| `MonthlyViewModel` | totals, grouping by category, uncheck all, delete |
| `ExpensesViewModel` | the four sections, totals, add/delete (including sub-values) |

The view reads its `@Query` arrays and hands them to the view model (or straight to a Domain function). Small forms and reusable rows — `AddEditFixedExpenseView`, `CategoryManagerView`, `CurrencyField`, `SummaryCard` — **stay plain views**; a view model there would be ceremony.

### 2.3 Folder layout

Same single target, just grouped:

```
Sources/
  App/            BudgetAppApp.swift  (+ seeding, moved out of the views)
  Models/         Transaction, FixedExpense, NonFixedExpense, ExpenseCategory
  Domain/         BalanceRules, MonthlyTotals, NonFixedExpense+Rules, Currency
  Data/           AccountsStore, BackupService, BackupFile
  Features/
    Transactions/ MonthView, TransactionsViewModel, AddTransactionView(+VM), TransactionRow, SummaryCard, BalanceDistributionSection
    Monthly/      MonthlyView, MonthlyViewModel, AddEditFixedExpenseView, CategoryManagerView
    Expenses/     ExpensesView, ExpensesViewModel, AddMoreExpenseView, SubExpensesView
  Shared/         CurrencyField, DismissKeyboardOnTap, Color+Hex
Tests/            DomainTests (new unit-test target)
```

### 2.4 Deliberately left out

- **Repository protocols / use-case classes / dependency-injection container** — one data source, one developer; `ModelContext` already is the repository.
- **Coordinators / router** — three tabs and a few sheets.
- **TCA or Clean Architecture** — far more structure than ~2,600 lines need.
- **Multiple modules / Swift packages** — folders are enough.

Revisit only if the app gains sync, multiple accounts, or a second platform.

### 2.5 Suggested order (each step keeps behaviour identical)

1. **Domain + tests first.** Extract the formulas into `Domain/` and write unit tests that pin the rules in Part 1. This is the safety net for everything after.
2. **`AccountsStore`.** Replace the scattered `@AppStorage` / `UserDefaults` access.
3. **View models**, one screen at a time: Add Transaction → Transactions → Monthly → Expenses.
4. **Move files into folders** and move seeding out of the views.
5. **Then, separately, decide on the items in 1.8** — those are behaviour changes, not refactoring, and should not be mixed in.

On naming (1.8 #9): renaming a `@Model` class changes the stored schema, so keep the class names and fix vocabulary in the UI, docs and view-model names instead (e.g. "Transaction", "Monthly item", "Extra entry").
