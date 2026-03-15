---
name: wf-skill-testing-anti-patterns
description: Cross-cutting test quality rules cataloguing common testing mistakes. Referenced during build and review phases to prevent misleading, brittle, or worthless tests.
user-invocable: false
---

# Testing Anti-Patterns — What NOT to Do in Tests

## Purpose

Catalog the most common testing mistakes that produce tests which are misleading, brittle, or worthless. Each anti-pattern includes what it looks like, why it's harmful, and the correct alternative. This skill is referenced during build and review phases to ensure test quality.

## How to Use This Skill

- During **build**: Before writing any test, scan this list. If your test matches an anti-pattern, restructure it before committing.
- During **review**: Check submitted tests against this list. Any match is grounds for rejection with a specific citation.
- During **verification**: Tests that exhibit these anti-patterns do not count as valid evidence of correctness.

---

## Anti-Pattern 1: Testing Implementation, Not Behavior

### What it looks like
```python
# BAD: Testing that a specific internal method is called
def test_user_creation():
    service = UserService()
    service.create_user("Alice")
    assert service._hash_password.call_count == 1
    assert service._save_to_db.call_count == 1
```

### Why it's bad
The test is coupled to internal implementation details. If you refactor `create_user` to use a different internal structure (combining `_hash_password` and `_save_to_db` into a single method, for example), the test breaks — even though the behavior is identical. These tests punish refactoring and provide zero confidence that the feature actually works.

### Correct approach
```python
# GOOD: Testing the observable behavior
def test_user_creation():
    service = UserService(db=test_db)
    service.create_user("Alice", password="secret123")

    user = test_db.get_user("Alice")
    assert user is not None
    assert user.verify_password("secret123") is True
```

Test what the caller cares about: after calling `create_user`, a user exists and can authenticate. How the service achieves this internally is irrelevant to the test.

---

## Anti-Pattern 2: Mocking What You Own

### What it looks like
```python
# BAD: Mocking your own repository class
def test_order_total():
    mock_repo = Mock(spec=OrderRepository)
    mock_repo.get_items.return_value = [Item(price=10), Item(price=20)]
    service = OrderService(repo=mock_repo)

    total = service.calculate_total(order_id=1)
    assert total == 30
```

### Why it's bad
You are testing that `OrderService.calculate_total` correctly sums a list — but you've mocked away the real question: does `OrderRepository.get_items` actually return the right data for a given order? The mock encodes your assumption about what the repository returns, not its actual behavior. If the repository's return type changes, this test still passes — but production breaks.

### Correct approach
```python
# GOOD: Use a real (test) database or in-memory implementation
def test_order_total():
    repo = InMemoryOrderRepository()
    repo.save_order(Order(id=1, items=[Item(price=10), Item(price=20)]))
    service = OrderService(repo=repo)

    total = service.calculate_total(order_id=1)
    assert total == 30
```

Mock at boundaries you don't own (external APIs, third-party services). For your own code, use real implementations or in-memory fakes that implement the same interface.

---

## Anti-Pattern 3: Assertions That Pass With Deleted Implementation

### What it looks like
```python
# BAD: Assertion that proves nothing
def test_process_data():
    result = process_data([1, 2, 3])
    assert result is not None
    assert isinstance(result, list)
```

### Why it's bad
Delete the implementation of `process_data` and replace it with `return []`. The test still passes. A test that passes with a trivially wrong implementation is not testing anything meaningful. It gives false confidence.

### Correct approach
```python
# GOOD: Assert on specific, meaningful values
def test_process_data_doubles_each_value():
    result = process_data([1, 2, 3])
    assert result == [2, 4, 6]
```

The litmus test: could you delete or fundamentally break the implementation and have this test still pass? If yes, the assertion is too weak.

---

## Anti-Pattern 4: Testing Private Methods

### What it looks like
```python
# BAD: Reaching into private internals
def test_parse_internal_format():
    service = DataService()
    result = service._parse_internal_format("raw data")
    assert result == {"key": "value"}
```

### Why it's bad
Private methods are implementation details. They exist to support public behavior. Testing them directly couples your test suite to the internal structure, making refactoring painful. If `_parse_internal_format` is important enough to test, it should either be a public method on a separate class or tested through the public interface that uses it.

### Correct approach
```python
# GOOD: Test through the public interface
def test_data_import():
    service = DataService()
    service.import_data("raw data")

    assert service.get_record("key") == "value"
```

If a private method has complex logic worth testing independently, that's a design signal: extract it into its own class with a public interface.

---

## Anti-Pattern 5: Snapshot Overuse

### What it looks like
```javascript
// BAD: Snapshotting everything
test('renders user profile', () => {
  const component = render(<UserProfile user={testUser} />);
  expect(component).toMatchSnapshot();
});
```

### Why it's bad
Snapshot tests are easy to write but provide weak guarantees. When they fail, the most common response is to blindly update the snapshot (`--updateSnapshot`) without reviewing the diff. They test the entire output structure, so any change (even intentional ones) causes a failure. This leads to snapshot update fatigue where real regressions get waved through.

### Correct approach
```javascript
// GOOD: Test specific behaviors
test('renders user name and email', () => {
  const { getByText } = render(<UserProfile user={testUser} />);
  expect(getByText('Alice Smith')).toBeInTheDocument();
  expect(getByText('alice@example.com')).toBeInTheDocument();
});

test('shows premium badge for premium users', () => {
  const { getByTestId } = render(<UserProfile user={premiumUser} />);
  expect(getByTestId('premium-badge')).toBeInTheDocument();
});
```

Use snapshots sparingly and only for genuinely stable structures (e.g., API response schemas, serialization formats). For UI and behavior, test specific properties.

---

## Anti-Pattern 6: Test Names That Don't Describe the Scenario

### What it looks like
```python
# BAD: Vague, meaningless names
def test_calculate():
    ...

def test_user_service():
    ...

def test_edge_case():
    ...
```

### Why it's bad
When this test fails in CI, the developer sees "test_calculate FAILED" and learns nothing. They have to read the entire test body to understand what scenario broke. Good test names are documentation: they describe what should happen, under what conditions.

### Correct approach
```python
# GOOD: Name describes the scenario and expected behavior
def test_calculate_total_with_discount_applies_percentage_to_subtotal():
    ...

def test_user_service_rejects_duplicate_email_with_conflict_error():
    ...

def test_empty_cart_returns_zero_total():
    ...
```

Follow the pattern: `test_<action>_<scenario>_<expected_result>`. When the test fails, the name alone should tell you what broke.

---

## Anti-Pattern 7: Shared Mutable State Between Tests

### What it looks like
```python
# BAD: Tests share and mutate a class-level variable
class TestOrderProcessing:
    orders = []  # Shared across all tests

    def test_add_order(self):
        self.orders.append(Order(id=1))
        assert len(self.orders) == 1

    def test_remove_order(self):
        self.orders.pop()
        assert len(self.orders) == 0  # Depends on test_add_order running first
```

### Why it's bad
Tests depend on execution order. Run them in isolation and they fail. Run them in a different order and they fail. Parallel execution is impossible. One failing test can cascade into false failures in subsequent tests, making debugging a nightmare.

### Correct approach
```python
# GOOD: Each test creates its own state
class TestOrderProcessing:
    def test_add_order(self):
        orders = []
        orders.append(Order(id=1))
        assert len(orders) == 1

    def test_remove_order(self):
        orders = [Order(id=1)]
        orders.pop()
        assert len(orders) == 0
```

Each test must set up its own state, execute, and tear down independently. Use `setUp`/`tearDown` (or `beforeEach`/`afterEach`) for common setup, but never share mutable data.

---

## Anti-Pattern 8: Ignoring Error Paths

### What it looks like
```python
# BAD: Only testing the happy path
def test_transfer_money():
    result = transfer(from_account=a, to_account=b, amount=100)
    assert result.success is True
# No tests for: insufficient funds, invalid account, negative amount,
# same source and destination, concurrent transfers, network failure...
```

### Why it's bad
Happy paths rarely break. Error paths break constantly — and they're where the worst bugs live (data corruption, security holes, silent failures). A test suite with only happy-path tests provides a false sense of coverage.

### Correct approach
```python
# GOOD: Test error paths explicitly
def test_transfer_succeeds_with_sufficient_funds():
    result = transfer(from_account=a, to_account=b, amount=100)
    assert result.success is True
    assert a.balance == 900
    assert b.balance == 1100

def test_transfer_fails_with_insufficient_funds():
    result = transfer(from_account=a, to_account=b, amount=99999)
    assert result.success is False
    assert result.error == "Insufficient funds"
    assert a.balance == 1000  # unchanged
    assert b.balance == 1000  # unchanged

def test_transfer_rejects_negative_amount():
    with pytest.raises(ValueError, match="Amount must be positive"):
        transfer(from_account=a, to_account=b, amount=-50)

def test_transfer_rejects_same_account():
    with pytest.raises(ValueError, match="Cannot transfer to same account"):
        transfer(from_account=a, to_account=a, amount=100)
```

For every feature, ask: "How can this fail? What invalid inputs are possible? What error should the user see?" Test those.

---

## Anti-Pattern 9: Only Testing the Happy Path

### What it looks like
This is closely related to Anti-Pattern 8 but focuses on missing boundary conditions:

```python
# BAD: Testing one "normal" case
def test_paginate():
    result = paginate(items=range(100), page=2, per_page=10)
    assert len(result) == 10
```

### Why it's bad
What about page 0? Page -1? Page 9999? `per_page=0`? An empty items list? A list with exactly `per_page` items? These boundaries are where bugs hide.

### Correct approach
```python
# GOOD: Test boundaries and edge cases
def test_paginate_returns_correct_page():
    result = paginate(items=range(100), page=2, per_page=10)
    assert result == list(range(10, 20))

def test_paginate_first_page():
    result = paginate(items=range(100), page=1, per_page=10)
    assert result == list(range(0, 10))

def test_paginate_last_page_partial():
    result = paginate(items=range(25), page=3, per_page=10)
    assert result == [20, 21, 22, 23, 24]

def test_paginate_empty_list():
    result = paginate(items=[], page=1, per_page=10)
    assert result == []

def test_paginate_beyond_last_page():
    result = paginate(items=range(10), page=5, per_page=10)
    assert result == []

def test_paginate_rejects_zero_per_page():
    with pytest.raises(ValueError):
        paginate(items=range(10), page=1, per_page=0)
```

---

## Anti-Pattern 10: Copy-Paste Test Blocks

### What it looks like
```python
# BAD: Nearly identical tests with minor variations
def test_parse_csv_with_commas():
    result = parse("a,b,c")
    assert result == ["a", "b", "c"]

def test_parse_csv_with_semicolons():
    result = parse("a;b;c")
    assert result == ["a", "b", "c"]

def test_parse_csv_with_tabs():
    result = parse("a\tb\tc")
    assert result == ["a", "b", "c"]

# 15 more nearly identical tests...
```

### Why it's bad
When the test structure needs to change (e.g., `parse` now returns tuples), you have to update 18 tests. Worse, copy-paste tests often have subtle copy-paste errors (forgot to change the delimiter in test 7, so it's actually testing commas twice). They bloat the test file and make it hard to see what's actually being tested.

### Correct approach
```python
# GOOD: Parameterized tests
@pytest.mark.parametrize("input_str,delimiter,expected", [
    ("a,b,c", ",", ["a", "b", "c"]),
    ("a;b;c", ";", ["a", "b", "c"]),
    ("a\tb\tc", "\t", ["a", "b", "c"]),
    ("single", ",", ["single"]),
    ("", ",", []),
])
def test_parse_csv(input_str, delimiter, expected):
    result = parse(input_str, delimiter=delimiter)
    assert result == expected
```

Use parameterized tests for variations on the same scenario. Reserve separate test functions for genuinely different scenarios that need different setup, assertions, or documentation.

---

## Quick Reference

| # | Anti-Pattern | One-Line Check |
|---|-------------|----------------|
| 1 | Testing implementation | Does refactoring break this test without changing behavior? |
| 2 | Mocking what you own | Am I mocking code I could use a real/fake implementation for? |
| 3 | Weak assertions | Would this pass if I deleted the implementation? |
| 4 | Testing private methods | Am I accessing `_` prefixed or internal-only members? |
| 5 | Snapshot overuse | Would I actually review this snapshot diff, or just update it? |
| 6 | Bad test names | Can I understand what broke from the name alone? |
| 7 | Shared mutable state | Can I run any test in isolation and get the same result? |
| 8 | Ignoring error paths | What happens when this function receives bad input? |
| 9 | Only happy path | Have I tested boundaries, empty inputs, and overflow cases? |
| 10 | Copy-paste tests | Are these tests identical except for one or two values? |

## The Meta-Rule

A good test has three properties:

1. **It fails when the feature breaks.** (Not too weak.)
2. **It passes when the feature works, regardless of implementation.** (Not too coupled.)
3. **When it fails, the name and output tell you what went wrong.** (Not too vague.)

If your test doesn't have all three, it needs rework.
