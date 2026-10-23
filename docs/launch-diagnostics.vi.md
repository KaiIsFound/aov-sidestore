# Chẩn đoán văng ở logo và bản đối chứng

Đây là quy trình kiểm tra bản gốc, chưa phải bản sửa đã xác nhận trên iPhone.
Workflow `Inspect original IPA launch baseline` lấy đúng IPA gốc đã cung cấp,
kiểm tra SHA-256 và CRC ZIP, rồi xuất lại nguyên file để thử bằng cùng SideStore.
Workflow không biên dịch hoặc chèn thư viện, không sửa bundle ID, không sửa
chữ ký và không giả phản hồi xác thực.

## Bằng chứng từ log và hai IPA

Log đã được đọc cục bộ. File log đầy đủ không được đưa lên repository.

- Tiến trình kết thúc bằng `EXC_CRASH / SIGABRT`, `Abort trap: 6`.
- Luồng chính có chuỗi gọi `aovnet + 0x150234` →
  `+[NSJSONSerialization JSONObjectWithData:options:error:]` →
  `objc_exception_throw` → `abort`.
- `OllieAOV.dylib` xuất hiện trong danh sách thư viện đã nạp. Không có bằng chứng
  `Library not loaded` trong lần văng này.
- `aovnet` ở điểm gọi có UUID `32dee092-3537-3de6-b18b-4fe89772c070`.
  UUID này khớp chính xác bản mod; bản gốc có UUID
  `92a2cb7d-e1cf-32f5-8139-07c461979acb`.
- Bản gốc và bản mod cùng phiên bản `1.64.11768577`, build
  `1.64.1.1768577`, và đều vượt qua kiểm tra CRC của toàn bộ ZIP.

| Dữ liệu | IPA gốc | IPA mod |
| --- | --- | --- |
| Dung lượng IPA | 209533502 byte | 423521172 byte |
| Dung lượng file aovnet | 1258624 byte | 12902948 byte |
| MinimumOSVersion trong Info.plist | 15.0 | 10.0 |
| SHA-256 file aovnet | `3ec81a5ac7881e2440a9183962e58507c61d1d09b87df6cded999adb5519c0bb` | `fd477f315aac91e2b580275593660eb9b74a99131e223f00b2a3a968ea37a420` |

UUID và kích thước khác nhau xác nhận đây là hai binary khác nhau. Riêng UUID
không chứng minh nguồn gốc, nội dung thay đổi hay chất lượng của binary.

## Điều đã biết và điều chưa biết

Điểm phát sinh exception đã được khoanh vùng ở lời gọi đọc JSON từ `aovnet`
của bản mod. Log không chứa exception reason hoặc dữ liệu đầu vào; chưa thể
kết luận là `nil`, sai loại dữ liệu, phản hồi mạng hay nguyên nhân khác.
Một frame trong `lastExceptionBacktrace` có tên symbol Foundation khác; chuỗi
trên dùng tên symbol trong `threads[0].frames`, nên cần symbolication với đúng
binary/dSYM nếu muốn xác định chính xác hơn.

Mã hiện tại còn chặn URL dựa trên các từ rất rộng như `api`, `auth`, `login`
và thay phản hồi bằng JSON giả. Đây là yếu tố gây nhiễu khi chẩn đoán khởi động;
chưa có bằng chứng đủ để quy riêng lần văng này cho hook đó. Biên dịch thành
công, ký ad-hoc hoặc thêm weak load không chứng minh chạy thành công.

## Kiểm tra tiếp trên iPhone

1. Chạy workflow mới sau khi nhánh chứa workflow được đưa vào nhánh mặc định.
2. Tải artifact `Original-IPA-Launch-Baseline`, giải nén lấy
   `original-baseline.ipa`. Đây vẫn là IPA gốc, chưa ký bằng tài khoản của bạn.
3. Thử cài bằng cùng SideStore và cùng thiết bị. Sao lưu dữ liệu trước nếu
   SideStore yêu cầu thay thế bản đã cài; không cần xóa app để làm phép thử này.
4. Ghi lại bản gốc có vượt qua logo và tải được hay không. Nếu vẫn văng,
   lấy log mới và đối chiếu module, UUID, stack trước khi sửa tiếp.

Nếu bản gốc chạy được, vấn đề được thu hẹp về các thay đổi của bản mod hoặc
phần chèn thêm. Nếu bản gốc cũng văng, cần kiểm tra tiếp bản game, ký ứng dụng,
môi trường SideStore và tương thích iOS. Phép thử này không hoàn thiện phần
bẻ khóa key, giả xác thực hoặc khẳng định bản mod đã được sửa.

## Chạy kiểm tra cục bộ

Python 3.9 trở lên, chỉ dùng thư viện chuẩn:

```sh
python tools/inspect_ipa.py /path/to/original.ipa --output original-report.json
python tools/inspect_ipa.py /path/to/modified.ipa --output modified-report.json
```

Kiểm tra archive và Mach-O không thay thế kiểm thử trên thiết bị thật.
