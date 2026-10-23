# aov-sidestore

## Mở menu

- Bản build mới có nút tròn màu xanh **MENU** ở giữa mép trái màn hình, nằm trong vùng an toàn của iPhone.
- Chạm để mở bảng cài đặt; bấm **Đóng** để đóng. Kéo nút MENU để đổi vị trí.
- Bảng có thể cuộn trên màn hình ngang. Chạm ngoài bảng vẫn điều khiển game bình thường.
- Nút được gắn khi cửa sổ game sẵn sàng và được kiểm tra lại mỗi giây khi ứng dụng đang hoạt động, kể cả sau khi game đổi giao diện. Không cần chờ `anogs` hay `UnityFramework` để hiển thị menu.
- Menu không tự ẩn khi chụp/quay màn hình; cấu hình `streamProof` cũ chưa có phần triển khai giao diện.

## Cài bản đã sửa

1. Dùng mã nguồn có bản sửa này (nếu lấy từ pull request thì chọn nhánh của pull request trong **Actions → Build Clean IPA For SideStore → Run workflow**).
2. Nhập đường dẫn IPA gốc mà bạn có quyền sử dụng vào `clean_ipa_url` rồi chạy workflow.
3. Tải artifact **File-IPA-Cho-SideStore**, giải nén và cài lại `Ollie_AOV_SideStore_Ready.ipa` qua SideStore. IPA đã cài trước đó không tự nhận mã mới từ GitHub.

Nếu không có nút sau khi cài bản mới, kiểm tra log thiết bị để tìm `[OllieAOV] MENU attached to game window`. Có dòng này nghĩa là thư viện đã chạy và gắn giao diện. Nếu không có, cần kiểm tra việc thư viện được nạp, chữ ký và đúng IPA đã cài; ảnh chụp màn hình không xác nhận được những bước đó.

## Giới hạn của mã hiện tại

Workflow đang biên dịch `dobby_stub.cpp`: hàm `DobbyHook` chỉ lưu địa chỉ gốc và trả về, **không cài hook thật**. Bản sửa menu không thay đổi điều đó. Các công tắc cập nhật cấu hình trong bộ nhớ, chưa chứng minh chức năng tương ứng hoạt động trong game. ESP, tự động Trừng Trị và ngắm Elsu cũng chưa có phần triển khai hoàn chỉnh trong mã nguồn hiện tại. Các offset có sẵn chưa được xác minh với bản game đang cài. Những mô tả “anti-ban 100%” trong mã cũ không phải bảo đảm đã kiểm chứng.

## Kiểm tra

Workflow **Validate Menu** biên dịch thư viện cho thiết bị iOS và chạy ứng dụng kiểm tra UIKit trên iOS Simulator, không cần tải IPA game. Kiểm tra bao gồm nút mở/đóng, truyền thao tác ngoài menu, cập nhật cấu hình, giới hạn vị trí sau xoay màn hình và gắn lại sau khi cửa sổ thay đổi.

Vẫn cần thử IPA trên iPhone thật: vào sảnh → mở/đóng menu → kéo nút → chuyển giao diện → đưa game ra nền và mở lại.
