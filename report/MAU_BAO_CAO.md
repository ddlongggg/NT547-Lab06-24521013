# NT547 - LAB 06 - BÁO CÁO (TỰ ĐIỀN)

**MSSV:** 24521013  | **Họ tên:** Tạ Đức Long | **Lớp:** NT547.R11.ANTT
**Session code tự sinh:** SC-28C875 | **Tên contract:** PiggyBank_1013
**Solidity / Slither:** 0.8.24 / ... | **Ngày hoàn thành:** ...
**URL GitHub repository:** ...

## 1. Static scan (2,0 điểm)

- Lệnh raw: `python tools/scan.py --mode raw --tag before`
- Số lượng finding raw từ `evidence/before_raw/summary.json`:
  - High: 5; Medium: 1; Low: 1; Informational: 3; Optimization: 1
- Chạy configured: `python tools/scan.py --mode configured --tag before`
- So sánh raw/configured: Bản raw ghi nhận tổng 11 finding (High: 5, Medium: 1, Low: 1, Informational: 3, Optimization: 1). Khi chuyển sang chế độ configured (áp dụng slither.config.json loại bỏ Low, Informational và detector solc-version), tổng số finding giảm còn 7, nhưng toàn bộ 5 finding mức High và 1 finding mức Medium vẫn giữ nguyên, không bị ẩn đi (không biến mất High/Medium khi chỉ đổi config)
- 3 detector **khác tên**: 

| ID finding | Detector | Impact | Confidence | Source (file:dòng) | Luồng dữ liệu: đầu vào -> thao tác -> tác hại |
|---|---|---|---|---|---|
| F01 | suicidal | High | High | AuditTarget.sol:destroyPool:45,46,47 | Bất kỳ người gọi bên ngoài nào (không qua kiểm tra quyền onlyOwner) → gọi hàm destroyPool() thực thi lệnh selfdestruct(payable(msg.sender)) → toàn bộ số dư ETH trong hợp đồng bị rút sạch về ví kẻ tấn công |
| F02 | tx-origin | Medium | Medium | AuditTarget.sol:updateOwner:61 | Chủ sở hữu (owner) bị dụ gọi giao dịch thông qua một hợp đồng trung gian độc hại → hàm updateOwner() kiểm tra quyền bằng tx.origin == owner tại dòng 61 thay vì msg.sender → kẻ tấn công chiếm đoạt quyền sở hữu hợp đồng |
| F03 | weak-prng | High | Medium | AuditTarget.sol:weekdayIndex:75 | Giá trị thời gian khối block.timestamp → đưa vào phép chia lấy dư (block.timestamp / 86400 + 4) % 7 trong hàm view weekdayIndex() → tính toán chỉ số ngày trong tuần để hiển thị (không dùng để cấp quyền hay chia thưởng nên không gây thiệt hại tài sản) |

## 2. Triage và sửa lỗi (2,5 điểm)

Đọc toàn bộ AuditTarget.sol: nhận diện **4 mẫu lỗi thật + 2 đoạn cần đánh giá ngữ cảnh**,
kể cả khi Slither không hiển thị đủ 6 cảnh báo. Với mẫu không có detector,
ghi “Manual review / Not reported”, KHÔNG sửa slither.json hoặc tạo finding giả.

| Detector + vị trí | TP / FP / Chưa kết luận | Bằng chứng kiểm soát/khả năng khai thác | Biện pháp (Fix / Accept có lý do) | Sau sửa |
|---|---|---|---|---|
| | | | | |
| | | | | |
| | | | | |
| | | | | |
| | | | | |
| | | | | |

- Mô tả ít nhất 01 kịch bản khai thác TP: người gọi -> điều kiện -> call/state -> hậu quả: ...
- Phân tích 01 finding có severity cao nhưng risk thực tế không tương ứng: ...
- Dẫn bằng chứng `git diff`, scan before/after và giải thích cảnh báo còn lại: ...
- Lý do của mọi `slither-disable-next-line`: ... (tên detector, đúng vị trí, kiểm soát bù trừ).

## 3. Kiến trúc / Inheritance (1,5 điểm)

- Lệnh printer đã chạy: ...
- Ảnh `evidence/architecture/inheritance.png` (hoặc .dot, nếu Graphviz chưa có): ...
- Access control nằm ở ...; logic số dư nằm ở ...; contract triển khai nằm ở ...
- Giải thích 3–5 câu điểm audit cần bắt đầu: ...

## 4. Red -> Green CI (2,5 điểm)

| Phase | Commit (full/short SHA) | Run URL | Kết quả | Detector khiến RED / lý do GREEN |
|---|---|---|---|---|
| Baseline vulnerable | | | RED | |
| Patched | | | GREEN | |

- So sánh local `--fail-none` (thu thập findings) với CI `fail-on: medium`: ...
- `exclude_low/informational` thay đổi kết quả hiển thị ra sao: ...

## 5. Mutation RED -> GREEN (1,5 điểm)

- Mutation một dòng: `require(msg.sender == owner, "not owner")` -> `require(tx.origin == owner, "not owner")` trong `modifier onlyOwner`.
- Detector kỳ vọng: `tx-origin` (mức Medium); xác nhận của em từ CI: ...

| Phase | Commit SHA | Run URL | Kết quả |
|---|---|---|---|
| Mutation | | | RED |
| Revert mutation | | | GREEN |

- Giải thích sự thay đổi về nguồn định danh/authorization: ...

## 6. Bằng chứng, tự kiểm

- [ ] `AuditTarget.sol`, `lab_identity.json`
- [ ] `evidence/before_raw/` và `evidence/before_configured/`
- [ ] `evidence/after_raw/` và `evidence/after_configured/`
- [ ] `evidence/architecture/`
- [ ] 04 URL Actions run RED/GREEN/RED/GREEN + 04 commit SHA
- [ ] Link repo và ảnh màn hình có terminal / URL / commit SHA; không cắt mất ngữ cảnh
- [ ] Các finding được triage, không chép lại mô tả detector thay cho suy luận
- [ ] Tuyệt đối không có seed phrase, private key, credentials

**Nhận xét cuối cùng (5–7 câu):** ...
