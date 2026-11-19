# NT547 - LAB 06 - BÁO CÁO (TỰ ĐIỀN)

**MSSV:** 24521013  | **Họ tên:** Tạ Đức Long | **Lớp:** NT547.R11.ANTT
**Session code tự sinh:** SC-28C875 | **Tên contract:** PiggyBank_1013
**Solidity / Slither:** 0.8.24 / ... | **Ngày hoàn thành:** ...
**URL GitHub repository:** https://github.com/ddlongggg/NT547-Lab06-24521013

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
| suicidal + AuditTarget.sol:destroyPool:45-47 | TP | Hàm destroyPool() để external không có onlyOwner, ai gọi cũng kích hoạt được selfdestruct(payable(msg.sender)) để rút sạch toàn bộ ETH của hợp đồng về ví kẻ tấn công | Fix: Thêm onlyOwner và thay selfdestruct bằng lệnh chuyển ETH an toàn về owner (hoặc khóa quyền gọi chỉ cho owner) | Đã xử lý (hết cảnh báo) |
| arbitrary-send-eth + AuditTarget.sol:payout:66-68 | TP | Hàm payout(to, amount) không kiểm soát quyền truy cập (onlyOwner) và không kiểm tra to != address(0), cho phép bất kỳ ai rút ETH ra địa chỉ tùy ý | Fix: Thêm onlyOwner, kiểm tra to != address(0) và số dư hợp đồng, dùng .call kiểm tra ok | Đã xử lý (hết cảnh báo) |
| uninitialized-state + AuditTarget.sol:treasury:15,70-72 | TP | Biến trạng thái treasury không được khởi tạo nên mặc định mang giá trị address(0). Khi gọi payTreasury(), một nửa số dư ETH sẽ bị gửi vào địa chỉ đốt 0x0 và mất vĩnh viễn | Fix: Khởi tạo treasury = payable(msg.sender) trong constructor(), thêm hàm setTreasury (onlyOwner) và kiểm tra treasury != address(0) | Đã xử lý (hết cảnh báo) |
| reentrancy-eth (High) + AuditTarget.sol:redeemSafe:53-58 | Accepted (Contextual) | Hàm gọi msg.sender.call trước khi gán held[msg.sender] = 0 nên Slither báo High, nhưng thực tế không thể khai thác vì hàm đã được bảo vệ bởi modifier khóa chống tái nhập (mutex) | Fix ưu tiên theo CEI: Đưa held[msg.sender] = 0; lên trước lệnh .call để tuân thủ Checks-Effects-Interactions và triệt tiêu cảnh báo | Đã xử lý (hết cảnh báo) |
| weak-prng (High) + AuditTarget.sol:weekdayIndex:74-76 | Accepted (Contextual) | Hàm view tính (block.timestamp / 86400 + 4) % 7 chỉ để lấy chỉ số thứ trong tuần (0–6) phục vụ hiển thị UI, không dùng làm nguồn ngẫu nhiên chia thưởng hay cấp quyền | Accept có lý do: Giữ nguyên logic hàm view và đặt // slither-disable-next-line weak-prng ngay trước dòng return | Đã xử lý (suppressed có chứng minh) |
| tx-origin + AuditTarget.sol:updateOwner:61 | TP | Dùng require(tx.origin == owner): nếu owner tương tác với một hợp đồng độc hại trung gian, hợp đồng đó có thể gọi chéo updateOwner(attacker) để chiếm quyền sở hữu | Fix: Đổi tx.origin thành msg.sender (hoặc gắn modifier onlyOwner) | Đã xử lý (hết cảnh báo) |

SỬA CODE (AuditTarget.sol):
1. Trong constructor() - khởi tạo biến treasury (sửa lỗi uninitialized-state):
Từ:
    constructor() {
        owner = msg.sender;
    }
THÀNH:
    constructor() {
        owner = msg.sender;
        treasury = payable(msg.sender);
    }
2. Tại hàm destroyPool() (dòng 45–47) - sửa lỗi suicidal:
TỪ:
    function destroyPool() external {
        selfdestruct(payable(msg.sender));
    }
THÀNH:
    function destroyPool() external onlyOwner {
        (bool ok, ) = payable(owner).call{value: address(this).balance}("");
        require(ok, "destroy failed");
    }
3. Tại hàm redeemSafe() (dòng 53–58) - chuẩn hóa theo Checks-Effects-Interactions để hết cảnh báo reentrancy-eth:
TỪ:
    function redeemSafe() external oneAtATime {
        uint256 a = held[msg.sender];
        (bool ok, ) = msg.sender.call{value: a}("");
        require(ok, "send failed");
        held[msg.sender] = 0;
    }
THÀNH:
    function redeemSafe() external oneAtATime {
        uint256 a = held[msg.sender];
        require(a > 0, "empty");
        held[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: a}("");
        require(ok, "send failed");
    } 
LƯU Ý: Giữ nguyên tên modifier khóa chống tái nhập có sẵn trên dòng khai báo redeemSafe() trong file
4. Tại hàm updateOwner(address newOwner) (dòng 60–64) - sửa lỗi tx-origin:
TỪ: 
    function updateOwner(address newOwner) external {
        require(tx.origin == owner, "not owner");
        require(newOwner != address(0), "zero");
        owner = newOwner;
    }
THÀNH:
    function updateOwner(address newOwner) external {
        require(msg.sender == owner, "not owner");
        require(newOwner != address(0), "zero");
        owner = newOwner;
    }
5. Tại hàm payout(address payable to, uint256 amount) (dòng 66–68) - sửa lỗi arbitrary-send-eth:
TỪ:
    function payout(address payable to, uint256 amount) external {
        to.transfer(amount);
    }
THÀNH:
    function payout(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero");
        require(amount <= address(this).balance, "insufficient balance");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "payout failed");
    }
6. Tại hàm payTreasury() (dòng 70–72) - bổ sung kiểm tra treasury và hàm cập nhật an toàn:
TỪ:
    function payTreasury() external onlyOwner {
        treasury.transfer(address(this).balance / 2);
    }
THÀNH:
    function setTreasury(address payable newTreasury) external onlyOwner {
        require(newTreasury != address(0), "zero");
        treasury = newTreasury;
    }
    function payTreasury() external onlyOwner {
        require(treasury != address(0), "zero treasury");
        (bool ok, ) = treasury.call{value: address(this).balance / 2}("");
        require(ok, "treasury failed");
    }
7. Tại hàm weekdayIndex() (dòng 74–76) - đặt suppression có kiểm soát cho weak-prng:
TỪ:
    function weekdayIndex() external view returns (uint256) {
        return (block.timestamp / 1 days + 4) % 7;
    }
THÀNH: 
    function weekdayIndex() external view returns (uint256) {
        // slither-disable-next-line weak-prng
        return (block.timestamp / 1 days + 4) % 7;
    }

- Mô tả ít nhất 01 kịch bản khai thác TP: người gọi -> điều kiện -> call/state -> hậu quả: 
    + Kịch bản khai thác lỗi suicidal tại hàm destroyPool():
        ++ Người gọi: Bất kỳ tài khoản bên ngoài nào (Attacker) không cần quyền owner.
        ++ Điều kiện: Hợp đồng PiggyBank_1013 đang nắm giữ số dư ETH từ người dùng nạp vào qua save() / depositSafe(), trong khi hàm destroyPool() khai báo external mà thiếu modifier onlyOwner.
        ++ Call / State: Attacker gọi trực tiếp PiggyBank_1013.destroyPool(), kích hoạt lệnh selfdestruct(payable(msg.sender)).
        ++ Hậu quả: Toàn bộ số dư ETH của hợp đồng bị cưỡng chế chuyển hết về ví của Attacker. (Lưu ý kỹ thuật EVM: từ bản nâng cấp Cancun / EIP-6780, trong giao dịch thông thường selfdestruct chuyển toàn bộ ETH ra địa chỉ đích chứ không tự động xóa bytecode và storage của hợp đồng như trước, nhưng vẫn gây mất trắng toàn bộ tài sản của người dùng).
- Phân tích 01 finding có severity cao nhưng risk thực tế không tương ứng: 
    + Phân tích reentrancy-eth (Impact: High) tại hàm redeemSafe():
        ++ Nguyên nhân Slither báo High: Công cụ phát hiện lệnh gọi ngoài (bool ok, ) = msg.sender.call{value: a}("") thực hiện trước dòng cập nhật biến trạng thái held[msg.sender] = 0, vi phạm thứ tự mẫu Checks-Effects-Interactions.
        ++ Lý do risk thực tế không tương ứng (an toàn theo ngữ cảnh): Toàn bộ hàm redeemSafe() (cũng như depositSafe()) đã được gắn modifier khóa chống tái nhập oneAtATime (require(!mutex, "reentrant"); mutex = true; _; mutex = false;). Nếu kẻ tấn công dùng hợp đồng nhận ETH để gọi ngược lại redeemSafe() trong lúc giao dịch chưa kết thúc, biến mutex đang mang giá trị true sẽ khiến giao dịch lập tức revert, ngăn chặn hoàn toàn khả năng rút tiền nhiều lần. (Dù không khai thác được, bài làm vẫn đưa held[msg.sender] = 0 lên trước .call để chuẩn hóa code và triệt tiêu cảnh báo).
- Dẫn bằng chứng `git diff`, scan before/after và giải thích cảnh báo còn lại: 
    + Kết quả đối chiếu Before / After:
        ++ Ở chế độ configured: Số lượng cảnh báo giảm từ 6 finding (High: 5, Medium: 1) ở bản before_configured xuống còn 0 finding (High: 0, Medium: 0) ở bản after_configured, đáp ứng điều kiện vượt qua ngưỡng fail-on: medium của CI.   
        ++ Ở chế độ raw: Toàn bộ các lỗi High, Medium và Low đều đã biến mất; chỉ còn lại các cảnh báo mức Informational vô hại:
            +++ low-level-calls (Informational): Xuất hiện tại các hàm ownerWithdraw, destroyPool, redeemSafe, payout, payTreasury do sử dụng .call{value: ...}("") kèm kiểm tra require(ok). Đây là chuẩn thực hành khuyến nghị của Solidity hiện đại thay cho .transfer() (vốn giới hạn 2300 gas), không phải lỗ hổng bảo mật.
            +++ naming-convention (Informational): Cảnh báo tên hợp đồng PiggyBank_1013 chứa dấu gạch dưới _1013 (không theo chuẩn CapWords). Đây là định danh bắt buộc theo MSSV do script create_lab.py tạo ra nên được giữ nguyên.   
- Lý do của mọi `slither-disable-next-line`: ... (tên detector, đúng vị trí, kiểm soát bù trừ).
    + Trong toàn bộ AuditTarget.sol chỉ sử dụng 01 chỉ thị tắt cảnh báo cục bộ:
        ++ Tên detector: weak-prng
        ++ Vị trí đặt: Đặt chính xác tại dòng ngay phía trên biểu thức return (block.timestamp / 1 days + 4) % 7; bên trong hàm weekdayIndex().
        ++ Kiểm soát bù trừ & chứng minh an toàn: Hàm weekdayIndex() được khai báo với từ khóa external view (chỉ đọc dữ liệu, không thể thay đổi state và không thực hiện chuyển tiền), chỉ thực hiện phép chia nguyên block.timestamp / 86400 (1 days) để tính chỉ số ngày trong tuần (từ 0 đến 6) phục vụ mục đích hiển thị giao diện (UI). Biến block.timestamp hoàn toàn không được dùng làm nguồn sinh số ngẫu nhiên để quay thưởng, chia tài sản hay phân quyền, do đó việc thợ đào có thể tác động nhẹ lên timestamp khối không gây ra bất kỳ rủi ro bảo mật nào.

## 3. Kiến trúc / Inheritance (1,5 điểm)

- Lệnh printer đã chạy: ...
- Ảnh `evidence/architecture/inheritance.png` (hoặc .dot, nếu Graphviz chưa có): ...
- Access control nằm ở ...; logic số dư nằm ở ...; contract triển khai nằm ở ...
- Giải thích 3–5 câu điểm audit cần bắt đầu: ...

## 4. Red -> Green CI (2,5 điểm)

| Phase | Commit (full/short SHA) | Run URL | Kết quả | Detector khiến RED / lý do GREEN |
|---|---|---|---|---|
| Baseline vulnerable | fd65d96756194df50ba9fb8f0a90b66433566ae2 | https://github.com/ddlongggg/NT547-Lab06-24521013/actions/runs/44554335978 | RED | CI kích hoạt fail-on: medium và chặn pipeline do Slither phát hiện các lỗi từ mức Medium trở lên trong baseline: tx-origin (Medium), suicidal (High), arbitrary-send-eth (High), uninitialized-state (High), reentrancy-eth (High), weak-prng (High) |
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
