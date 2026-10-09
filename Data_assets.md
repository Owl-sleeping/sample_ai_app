# 活動分類モデルのデータ・比較記録

更新日: 2026-10-06

## 1. 参考にしたもの

- **UCI Human Activity Recognition Using Smartphones**: [UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/240/human%2Bactivity%2Brecognition%2Busing%2Bsmartphones)
- 30人がスマートフォンを腰に装着して行った6種類の活動を記録したデータセット。加速度・ジャイロは50 Hz、1窓は2.56秒（128点）、窓同士は50%重複する。
- ラベル: `WALKING`, `WALKING_UPSTAIRS`, `WALKING_DOWNSTAIRS`, `SITTING`, `STANDING`, `LAYING`
- データセットには、UCI作成の561特徴量と、加速度・ジャイロの窓時系列が含まれる。
- 学習用は7,352窓、公式テスト用は2,947窓。学習・テストは被験者単位で分けられている。
- 実験ノートブック: [`activity_classification.ipynb`](../activity_analysis/activity_classification.ipynb)
- 展開データ: `../activity_analysis/UCI HAR Dataset/UCI HAR Dataset/`
- ダウンロード時は外側のZIPにデータ本体の`UCI HAR Dataset.zip`が入っていたため、内側のZIPも展開した。

## 2. 自作で進めた手順

1. **UCI付属561特徴量で分類**し、単純な基準モデルとランダムフォレストを比較した。
2. **混同行列・特徴量重要度を確認**。歩行と階段、座位と立位が主な混同箇所と分かった。UCI特徴量の重要度上位には重力加速度のX・Y成分が多く、Z成分は少なかった。
3. **加速度の統計量を自作**。`total_acc`のX/Y/Zごとの値と3軸の大きさから18特徴量を作った。
4. **特徴量案を分けて比較**。周期・周波数、体の動き、姿勢・重力方向を別々に作り、単独利用とBaselineへの追加を評価した。
5. **ジャイロ特徴量を追加**し、ジャイロなし・あり、周期特徴量の追加を比較した。
6. 特徴量選択では、同じ被験者が学習・検証にまたがらないよう、`subject_train.txt`を使う被験者単位の5分割交差検証を用いた。

## 3. 使用した機械学習と特徴量

### 分類器

- **教師あり6クラス分類**。
- 基準: `DummyClassifier(strategy="most_frequent")`（最頻クラスを常に予測）。
- 主モデル: `RandomForestClassifier(n_estimators=200, random_state=42, n_jobs=-1)`。
- クラスごとの評価にはprecision、recall、F1と混同行列を使用。
- 特徴量比較では平均正解率に加えて活動ごとの再現率を確認。

### 自作した特徴量

| セット名 | 入力と計算内容 | 数 |
|---|---|---:|
| Baseline 18 | `total_acc`のX/Y/Zそれぞれの平均・標準偏差・最小・最大・平均絶対差分（15）、3軸magnitudeの平均・標準偏差・平均絶対差分（3） | 18 |
| Period | `body_acc` magnitudeのFFTから0.5〜3 Hz帯の最大周波数と帯域エネルギー | 2 |
| Body movement | `body_acc`の各軸とmagnitudeの標準偏差・RMS・平均絶対差分 | 12 |
| Posture | `total_acc - body_acc`で近似した重力ベクトルのX/Y/Z平均、roll・pitch | 5 |
| Gyro | ジャイロ各軸とmagnitudeの標準偏差・RMS・平均絶対差分 | 12 |

## 4. 結果

### 4.1 UCI付属561特徴量モデル（公式テスト）

| モデル | 正解率 |
|---|---:|
| 最頻クラス基準モデル | 0.182 |
| Random Forest・561特徴量 | 0.929 |

### 4.2 自作特徴量の初期比較（公式テスト）

| 特徴量 | 正解率 |
|---|---:|
| 3軸統計量のみ | 0.815 |
| 3軸統計量 + magnitude | 0.829 |
| Baseline 18 + Body movement | 0.848 |

3軸にmagnitudeを加えたとき、正解率は約1.39ポイント上昇。混同行列では通常歩行の正解が増え、座位・立位の誤認は少し増える傾向があった。

### 4.3 自作特徴量セット単独（被験者単位5分割交差検証）

| 特徴量 | 平均正解率 ± 標準偏差 |
|---|---:|
| Baseline 18 | 0.854 ± 0.045 |
| Periodのみ | 0.408 ± 0.022 |
| Body movementのみ | 0.726 ± 0.012 |
| Postureのみ | 0.572 ± 0.013 |

### 4.4 Baselineへの追加（被験者単位5分割交差検証）

| 特徴量 | 平均正解率 ± 標準偏差 |
|---|---:|
| Baseline 18 | 0.854 ± 0.045 |
| Baseline + Period | 0.856 ± 0.037 |
| Baseline + Body movement | **0.869 ± 0.038** |
| Baseline + Posture | 0.837 ± 0.048 |

Body movement追加は5 Fold中4 Foldで改善し、Fold別改善幅は+2.46、+3.01、+2.31、+0.14、−0.29ポイント。現時点での基準候補に選んだ。

### 4.5 ジャイロ・周期特徴量の追加（被験者単位5分割交差検証）

| モデル | Fold別正解率 | 平均正解率 ± 標準偏差 |
|---|---|---:|
| Baseline + Body + Gyro | 0.827, 0.880, 0.925, 0.857, 0.927 | 0.883 ± 0.043 |
| Baseline + Body + Gyro + Period | 0.829, 0.888, 0.922, 0.867, 0.919 | **0.885 ± 0.039** |

周期追加で平均正解率は0.2ポイント上昇したが、活動間のトレードオフがある。上りを含む全クラスにとって明確な改善とはまだ言えない。

### 4.6 活動ごとの再現率（被験者単位5分割のout-of-fold予測）

| 活動 | Baseline 18 | + Body | + Body + Gyro | + Body + Gyro + Period |
|---|---:|---:|---:|---:|
| WALKING | 0.790 | 0.848 | 0.819 | 0.830 |
| WALKING_UPSTAIRS | 0.881 | 0.884 | 0.895 | 0.876 |
| WALKING_DOWNSTAIRS | 0.810 | 0.820 | 0.842 | 0.853 |
| SITTING | 0.820 | 0.830 | 0.869 | 0.875 |
| STANDING | 0.806 | 0.820 | 0.866 | 0.868 |
| LAYING | 1.000 | 1.000 | 1.000 | 0.999 |

- Body movement追加はWALKINGの再現率を0.790から0.848へ改善し、他クラスも同等以上だった。
- Gyro追加は階段上り・下りとSITTING/STANDINGを改善した一方、WALKINGは0.848から0.819へ低下。
- GyroモデルへのPeriod追加はWALKINGと階段下りを約1.1ポイント改善したが、階段上りは約1.9ポイント低下。
- LAYINGはほぼ完全に検出。out-of-fold予測では1,407件をすべて検出し、SITTING 6件をLAYINGと誤認したため、LAYING precisionは0.996、recallは1.000。Z軸が理由とは確認できていない。

### 4.7 Baseline + Bodyの公式テスト結果

- 正解率: **0.848**

| 活動 | Precision | Recall | F1 | テスト件数 |
|---|---:|---:|---:|---:|
| WALKING | 0.78 | 0.89 | 0.83 | 496 |
| WALKING_UPSTAIRS | 0.79 | 0.79 | 0.79 | 471 |
| WALKING_DOWNSTAIRS | 0.94 | 0.80 | 0.86 | 420 |
| SITTING | 0.79 | 0.79 | 0.79 | 491 |
| STANDING | 0.81 | 0.81 | 0.81 | 532 |
| LAYING | 1.00 | 1.00 | 1.00 | 537 |

階段下りは「下り」と予測したときのprecisionが0.94だが、実際の下りを見つけるrecallは0.80。階段上りはprecision・recallとも約0.79。歩行と階段、座位と立位が主な誤認ペア。

## 現在の判断・次の課題

- 基準候補は **Baseline + Body movement**。単純な加速度統計量から始めたモデルとして、被験者単位CVで0.869、公式テストで0.848。
- GyroやPeriodは改善候補として残すが、階段上り・平地歩行など活動別にトレードオフがあるため、全体正解率だけで採否を決めない。
- 次は階段上り・下りと歩行の誤分類を重点的に減らす。モデル比較では同じ被験者単位5分割を使い、活動ごとの再現率と混同行列も追う。
- 公式テスト結果と交差検証結果は評価対象が異なるため、数値を直接同一視しない。
- このモデルは腰に固定した端末のデータで学習したもの。実アプリへの適用時は、アプリのセンサー軸・窓幅・サンプリング・前処理を合わせて別途検証する必要がある。
