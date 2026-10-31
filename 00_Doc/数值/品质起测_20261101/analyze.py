"""Read a UE-exported quality baseline and write planning artifacts beside this script.
No production CSV, source code or asset is written; no application/import mode exists.
"""
import argparse
import csv
from decimal import Decimal, localcontext
from fractions import Fraction as F
import hashlib
import io
import json
from pathlib import Path
import re

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[2]
DEFAULT_BASELINE = OUT / 'DT_Quality_runtime_snapshot.csv'
SOURCE = REPO / '02_Prototype/AlchemyHD2D/Source/AlchemyHD2D/AlchemyWorld.cpp'
LABELS = ('low', 'mid', 'high')
EXPECTED_PROC = tuple(map(F, ('5', '4.43', '3.86', '3.29', '2.71', '2.14', '1.57', '1')))


def decimal(value, places=12):
    if value is None:
        return ''
    with localcontext() as ctx:
        ctx.prec = 60
        return format(Decimal(value.numerator) / Decimal(value.denominator), f'.{places}f')


def exact(value):
    if isinstance(value, F):
        return {'fraction': f'{value.numerator}/{value.denominator}', 'decimal': decimal(value)}
    if isinstance(value, dict):
        return {k: exact(v) for k, v in value.items()}
    if isinstance(value, (tuple, list)):
        return [exact(v) for v in value]
    return value


def target(n):
    x = F(n - 3, 7)
    return (70 - 50*x, 20 + 15*x, F(10) + 35*x)


def nuclear(weights):
    l, m, h = weights
    return (l + (m+h)/2, m/2, h/2)


def filtered(weights, mask):
    remaining = tuple(w if mask & (1 << i) else F(0) for i, w in enumerate(weights))
    total = sum(remaining)
    return tuple(w/total for w in remaining) if total else None


def chase_high(probabilities):
    """Accept high; otherwise reroll once, excluding the initial quality.
    If no other candidate is available, keep the initial result.
    """
    high = probabilities[2]
    return high + sum(probabilities[i]*high/(1-probabilities[i])
                      for i in (0, 1) if probabilities[i] < 1)


def enumerate_chase(probabilities):
    # Independent draw-tree enumeration for verification, not the closed formula.
    win = F(0)
    for initial in range(3):
        if initial == 2:
            win += probabilities[initial]
            continue
        alternatives = [(i, p) for i, p in enumerate(probabilities) if i != initial and p]
        mass = sum(p for i, p in alternatives)
        if mass:
            for i, p in alternatives:
                if i == 2:
                    win += probabilities[initial] * p / mass
    return win


def self_check():
    for n in range(3, 11):
        w = target(n)
        assert sum(w) == 100 and all(v >= 0 for v in w)
        assert sum(nuclear(w)) == 100
        assert sum(F(decimal(v, 6)) for v in w) == 100
        for mask in range(8):
            for state in (w, nuclear(w)):
                q = filtered(state, mask)
                if mask == 0:
                    assert q is None
                else:
                    assert sum(q) == 1 and chase_high(q) == enumerate_chase(q)
    normal3 = filtered(target(3), 7)
    nuke3 = filtered(nuclear(target(3)), 7)
    assert chase_high(normal3) == F(43, 120)
    assert chase_high(nuke3) == F(61, 180)
    assert F(19, 20)*chase_high(normal3) + F(1, 20)*chase_high(nuke3) == F(2573, 7200)
    assert chase_high(filtered(target(10), 7)) == F(837, 1040)
    assert chase_high(filtered(nuclear(target(10)), 7)) == F(537, 880)
    assert F(99, 100)*F(837, 1040) + F(1, 100)*F(537, 880) == F(459237, 572000)
    assert filtered(nuclear(target(10)), 6)[1:] == (F(7, 16), F(9, 16))
    assert chase_high(filtered((F(30), F(35), F(35)), 7)) == F(179, 260)


def read_baseline(path):
    raw = path.read_bytes()
    reader = csv.DictReader(io.StringIO(raw.decode('utf-8-sig')))
    assert reader.fieldnames and {'Low', 'Mid', 'High'} <= set(reader.fieldnames), 'Unexpected quality schema.'
    key = reader.fieldnames[0]
    result = {}
    for row in reader:
        index = int(row[key])
        assert index not in result, 'Duplicate quality row ID.'
        w = tuple(F(row[column]) for column in ('Low', 'Mid', 'High'))
        assert all(v >= 0 for v in w) and sum(w) > 0, 'Invalid baseline weights.'
        result[index] = w
    assert sorted(result) == list(range(8)), 'Expected rows 0..7 for material counts 3..10.'
    canonical = raw.decode('utf-8-sig').replace('\r\n', '\n').replace('\r', '\n').encode('utf-8')
    return result, hashlib.sha256(canonical).hexdigest()


def read_proc():
    text = SOURCE.read_text(encoding='utf-8-sig')
    match = re.search(r'const float SpecialProcChance\[8\]\s*=\s*\{([^}]+)\}', text)
    assert match, 'Could not locate the current native proc array.'
    values = tuple(F(v.strip().removesuffix('f')) for v in match[1].split(','))
    assert values == EXPECTED_PROC, 'Native proc array changed; review this planning baseline first.'
    return values


def model_row(name, n, weights, mask, proc):
    ordinary = filtered(weights, mask)
    special = filtered(nuclear(weights), mask)
    row = {'table': name, 'material_count': n, 'row_id': n-3, 'candidate_mask': mask,
           'eligible_qualities': '+'.join(LABELS[i] for i in range(3) if mask & (1 << i)),
           'can_submit': ordinary is not None, 'can_refresh_ordinary': ordinary is not None and sum(p > 0 for p in ordinary) > 1,
           'can_refresh_nuclear': special is not None and sum(p > 0 for p in special) > 1,
           'proc_source_percent': proc*100, 'proc_design_reference_percent': 5-4*F(n-3, 7),
           'proc_policy': 'Use rounded native array; exact design interpolation is reference only.',
           'equivalent_crafts_per_30_materials': F(30, n), 'whole_budget_crafts': 30//n,
           'whole_budget_materials_remaining': 30 % n}
    for i, quality in enumerate(LABELS):
        row[f'base_{quality}_weight'] = weights[i]
        row[f'nuclear_{quality}_weight'] = nuclear(weights)[i]
        row[f'ordinary_{quality}_probability'] = ordinary[i] if ordinary else None
        row[f'nuclear_{quality}_probability'] = special[i] if special else None
    metrics = {f'{state}_high_{strategy}': None
               for state in ('ordinary', 'nuclear', 'mixed') for strategy in ('initial', 'chase_reroll')}
    if ordinary is not None:
        assert special is not None
        assert chase_high(ordinary) == enumerate_chase(ordinary)
        assert chase_high(special) == enumerate_chase(special)
        for strategy, a, b in [('initial', ordinary[2], special[2]),
                               ('chase_reroll', chase_high(ordinary), chase_high(special))]:
            metrics[f'ordinary_high_{strategy}'] = a
            metrics[f'nuclear_high_{strategy}'] = b
            metrics[f'mixed_high_{strategy}'] = (1-proc)*a + proc*b
    row.update(metrics)
    for key, probability in metrics.items():
        row[key+'_equivalent_expected_per_30'] = F(30, n)*probability if probability is not None else None
        row[key+'_whole_budget_expected'] = (30//n)*probability if probability is not None else None
        row[key+'_whole_budget_at_least_one'] = 1-(1-probability)**(30//n) if probability is not None else None
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, default=DEFAULT_BASELINE, help='Read-only UE CSV export (QA may supply another export).')
    parser.add_argument('--self-check', action='store_true', help='Verify Fraction formulas and independent draw-tree anchors, without writing files.')
    args = parser.parse_args()
    self_check()
    if args.self_check:
        print('QUALITY_MODEL_SELF_CHECK_PASS; no files written')
        return
    baseline, digest = read_baseline(args.baseline)
    proc = read_proc()
    rows = [model_row(name, n, table[n-3], mask, proc[n-3]/100)
            for name, table in [('runtime_baseline', baseline), ('confirmed_target_not_applied', {i: target(i+3) for i in range(8)})]
            for n in range(3, 11) for mask in range(8)]
    assumptions = [
        'Planning model only. Target CSV is not loaded/imported into production; no apply mode exists.',
        'Non-tutorial ordinary-material crafting; exclude elite fixed recipes.',
        'Candidate subset remains fixed across crafts: no dynamic skill leveling, capacity change or recipe availability change.',
        'Nuclear transform happens BEFORE filtering and normalization; reroll uses the same transformed weights and never rechecks nuclear.',
        'Reroll scenarios assume unlocked, free once, used only when the first skill is not high; exclude the first result. If no alternative, retain it.',
        'All-empty candidates cannot submit; model probabilities and resulting yield metrics are null, not a successful zero-quality craft.',
        'Use current rounded native nuclear proc array to isolate base-quality-table changes; exact linear design p is a separate reference column.',
        'Equivalent per-30 expectation uses 30/n crafts as a rate comparison; it is not an executable fractional craft budget.',
        'Whole budget uses floor(30/n), shows leftover materials, and computes at least one high as 1-(1-h)^floor(30/n). Crafts are independent under the fixed-candidate assumption.',
        'No extra nuclear drops, recollection, kills, enemy density, elapsed play time, travel time or human balance claims are modeled.',
        'Weights and probability fractions are exact; CSV decimals are display values. Target CSV has six decimals and row_id=n-3.'
    ]
    document = {'status': 'confirmed design candidate; production application requires separate explicit authorization',
                'baseline_path': args.baseline.resolve().relative_to(REPO).as_posix() if args.baseline.resolve().is_relative_to(REPO) else args.baseline.name,
                'baseline_canonical_sha256': digest,
                'native_proc_source': SOURCE.relative_to(REPO).as_posix(), 'candidate_mask_bits': {'low': 1, 'mid': 2, 'high': 4},
                'probability_unit': '0..1 except fields ending _percent', 'assumptions': assumptions,
                'source_documents': ['00_Doc/协作策划/1.5系统.md', '00_Doc/协作策划/1.6数值.md'],
                'rows': exact(rows)}
    # All input parsing and model checks finish before these planning-only outputs are written.
    with (OUT/'DT_Quality_target.csv').open('w', encoding='utf-8', newline='') as stream:
        writer = csv.writer(stream, lineterminator='\n')
        writer.writerow(('---', 'Low', 'Mid', 'High'))
        for n in range(3, 11):
            writer.writerow((n-3, *(decimal(v, 6) for v in target(n))))
    with (OUT/'model.csv').open('w', encoding='utf-8-sig', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows({k: decimal(v) if isinstance(v, F) else '' if v is None else v for k, v in row.items()} for row in rows)
    (OUT/'model.json').write_text(json.dumps(document, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'QUALITY_MODEL_PASS rows={len(rows)} baseline_sha256={digest}; wrote only {OUT}')


if __name__ == '__main__':
    main()
