# NT547 - LAB 06 - BÁO CÁO (TỰ ĐIỀN)

**MSSV:** 24521013  | **Họ tên:** Tạ Đức Long | **Lớp:** NT547.R11.ANTT
**Session code tự sinh:** SC-28C875 | **Tên contract:** PiggyBank_1013
**Solidity / Slither:** 0.8.24 / 0.11.6 | **Ngày hoàn thành:** 1:00AM - 21/11/2026
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

- Lệnh printer đã chạy: python tools/print_arch.py (thực thi slither contracts/ArchitectureDemo.sol --print human-summary và --print inheritance-graph, sau đó render qua dot -Tpng)
- Ảnh `evidence/architecture/inheritance.png` (hoặc .dot, nếu Graphviz chưa có): Đã xuất thành công đồ thị kế thừa tại evidence/architecture/inheritance.png
- Access control nằm ở contract cha trừu tượng AccessManaged (biến admin và modifier onlyAdmin()); logic số dư nằm ở contract cha BalanceLedger (biến mapping(address => uint256) internal balances, hàm balanceOf và _credit); contract triển khai nằm ở contract con StudentAsset (kế thừa cả hai contract cha trên)
- Giải thích 3–5 câu điểm audit cần bắt đầu: Trong kiến trúc kế thừa của ArchitectureDemo.sol, các logic nhạy cảm về bảo mật (security-critical) nằm ở hai contract cha là AccessManaged (kiểm soát xác thực quyền quản trị qua onlyAdmin) và BalanceLedger (cập nhật trực tiếp trạng thái số dư nội bộ trong hàm _credit). Hàm đóng vai trò cổng vào từ bên ngoài (entrypoint) duy nhất thay đổi trạng thái là StudentAsset.mint(address to, uint256 amount) (cùng với hàm đọc BalanceLedger.balanceOf). Khi thực hiện kiểm toán (audit), kiểm toán viên nên bắt đầu từ entrypoint StudentAsset.mint() vì đây là bề mặt tấn công (attack surface) nơi dữ liệu không tin cậy từ người gọi bên ngoài đi vào hệ thống. Từ entrypoint này, quá trình audit sẽ lần ngược theo luồng thực thi lên các contract cha để kiểm tra tính chặt chẽ của điều kiện chặn quyền ở AccessManaged.onlyAdmin() và tính toàn vẹn của phép cộng số dư ở BalanceLedger._credit()

## 4. Red -> Green CI (2,5 điểm)

| Phase | Commit (full/short SHA) | Run URL | Kết quả | Detector khiến RED / lý do GREEN |
|---|---|---|---|---|
| Baseline vulnerable | fd65d96756194df50ba9fb8f0a90b66433566ae2 | https://github.com/ddlongggg/NT547-Lab06-24521013/actions/runs/44554335978 | RED | CI kích hoạt fail-on: medium và chặn pipeline do Slither phát hiện các lỗi từ mức Medium trở lên trong baseline: tx-origin (Medium), suicidal (High), arbitrary-send-eth (High), uninitialized-state (High), reentrancy-eth (High), weak-prng (High) |
| Patched | 3ce5b42bc12200e5ff9af4be497d92c93841aa5e | https://github.com/ddlongggg/NT547-Lab06-24521013/actions/runs/44573637618 | GREEN | Toàn bộ 4 lỗi thật (TP) và reentrancy-eth đã được vá trong code; cảnh báo ngữ cảnh weak-prng ở hàm view đã được kiểm soát bằng slither-disable-next-line, không còn finding mức Medium/High nào |

- So sánh local `--fail-none` (thu thập findings) với CI `fail-on: medium`: Script tools/scan.py chạy ở máy cục bộ sử dụng cờ --fail-none để Slither luôn trả về exit code 0 kể cả khi phát hiện lỗ hổng, giúp xuất đầy đủ dữ liệu JSON/CSV phục vụ phân loại (triage). Ngược lại, GitHub Actions cấu hình fail-on: medium đóng vai trò cổng kiểm soát chất lượng (quality gate), tự động đánh dấu thất bại (RED, exit code khác 0) ngay khi xuất hiện bất kỳ cảnh báo nào từ mức Medium trở lên
- `exclude_low/informational` thay đổi kết quả hiển thị ra sao: Thiết lập "exclude_low": true, "exclude_informational": true và "detectors_to_exclude": "solc-version" trong slither.config.json giúp lọc bỏ toàn bộ các cảnh báo nhiễu mức thấp và gợi ý tối ưu/quy ước đặt tên (như missing-zero-check, low-level-calls, naming-convention), giữ bảng kết quả tập trung hoàn toàn vào các rủi ro nghiêm trọng (High và Medium) mà không làm ẩn đi lỗi bảo mật thực sự

## 5. Mutation RED -> GREEN (1,5 điểm)

- Mutation một dòng: `require(msg.sender == owner, "not owner")` -> `require(tx.origin == owner, "not owner")` trong `modifier onlyOwner`.
- Detector kỳ vọng: `tx-origin` (mức Medium); xác nhận của em từ CI: Khi thử nghiệm đặt require(tx.origin == owner) trong modifier onlyOwner() (commit d763ba5), Slither 0.11.6 không phát hiện do detector tx-origin chỉ kiểm tra functions_declared mà bỏ qua modifier. Do đó, em đã hoàn tác và thực hiện mutation 1 dòng tương tự trong hàm updateOwner() (require(msg.sender == owner) → require(tx.origin == owner)), kích hoạt thành công CI RED với detector tx-origin (Medium), sau đó dùng git revert để đưa nhánh main về trạng thái GREEN

| Phase | Commit SHA | Run URL | Kết quả |
|---|---|---|---|
| Mutation | d763ba5 | https://github.com/ddlongggg/NT547-Lab06-24521013/actions/runs/44787189407 | RED |
| Revert mutation | 84698eb | https://github.com/ddlongggg/NT547-Lab06-24521013/actions/runs/44787685516 | GREEN |

- Giải thích sự thay đổi về nguồn định danh/authorization: Việc đổi điều kiện kiểm tra trong hàm updateOwner() từ msg.sender == owner sang tx.origin == owner đã làm thay đổi bản chất xác thực từ người gọi trực tiếp (immediate caller) sang tài khoản EOA khởi tạo giao dịch gốc ban đầu (transaction origin). Trong EVM, tx.origin giữ nguyên địa chỉ của người khởi tạo xuyên suốt toàn bộ chuỗi gọi hàm nội bộ giữa các smart contract. Do đó, nếu chủ sở hữu (owner) vô tình tương tác với một hợp đồng độc hại bên ngoài (ví dụ qua một giao dịch nhận thưởng giả mạo), hợp đồng trung gian đó có thể gọi tiếp tới PiggyBank_1013.updateOwner(attackerAddress) và vượt qua hoàn toàn bước kiểm tra quyền vì tx.origin vẫn là owner. Hậu quả là kẻ tấn công chiếm được quyền owner và rút toàn bộ ETH của hợp đồng thông qua các hàm onlyOwner (ownerWithdraw, destroyPool, payout, payTreasury). Lệnh git revert khôi phục lại msg.sender, buộc người gọi trực tiếp hàm phải chính là owner và loại bỏ lỗ hổng chiếm quyền qua hợp

## 6. Bằng chứng, tự kiểm

- [ ] `AuditTarget.sol`, `lab_identity.json`
- [ ] `evidence/before_raw/` và `evidence/before_configured/`
- [ ] `evidence/after_raw/` và `evidence/after_configured/`
- [ ] `evidence/architecture/`
- [ ] 04 URL Actions run RED/GREEN/RED/GREEN + 04 commit SHA
- [ ] Link repo và ảnh màn hình có terminal / URL / commit SHA; không cắt mất ngữ cảnh
- [ ] Các finding được triage, không chép lại mô tả detector thay cho suy luận
- [ ] Tuyệt đối không có seed phrase, private key, credentials

**Nhận xét cuối cùng (5–7 câu):** Qua bài thực hành NT547 Lab 06, em đã nắm vững quy trình kết hợp phân tích tĩnh bằng Slither với cổng kiểm soát bảo mật tự động trên GitHub Actions CI/CD. Trên hợp đồng mục tiêu PiggyBank_1013, bước phân loại (triage) theo ngữ cảnh mã nguồn đóng vai trò then chốt để tách bạch các lỗ hổng thực sự nghiêm trọng (suicidal, tx-origin, arbitrary-send-eth, uninitialized-state) khỏi các cảnh báo an toàn theo thiết kế (reentrancy-eth đã được bảo vệ bởi oneAtATime và weak-prng tại hàm view). Việc tinh chỉnh slither.config.json giúp loại bỏ hiệu quả các cảnh báo nhiễu mức Low và Informational, giữ kết quả quét tập trung vào các rủi ro cốt lõi mà không che giấu lỗi bảo mật. Chu trình kiểm thử RED -> GREEN -> RED -> GREEN trên GitHub Actions với ngưỡng fail-on: medium đã chứng minh khả năng tự động chặn đứng mã nguồn không an toàn ngay từ giai đoạn tích hợp. Đồng thời, thử nghiệm mutation tx-origin cũng chỉ ra giới hạn của công cụ phân tích tĩnh (như việc Slither 0.11.6 bỏ qua kiểm tra bên trong modifier), qua đó khẳng định tự động hóa CI/CD cần luôn song hành cùng quá trình rà soát mã nguồn thủ công của kiểm toán viên. Sự kết hợp giữa cấu hình công cụ chuẩn xác, ghi nhận quyết định triage minh bạch và kiểm soát cổng tự động chính là nền tảng để đảm bảo an toàn bền vững cho smart contract trong thực tế.
