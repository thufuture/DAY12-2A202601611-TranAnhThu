# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trần Anh Thư       Mã học viên: 2A202601611

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Giả sử mình deploy lên Railway nhưng quên set biến `AGENT_API_KEY` trên
> dashboard. Nếu `agent_api_key` có giá trị mặc định `"changeme"`, app vẫn
> khởi động và chạy bình thường — service có vẻ hoạt động tốt, không ai báo
> lỗi. Nhưng vì `"changeme"` là giá trị công khai (ai đọc source code cũng
> biết), bất kỳ ai cũng gọi được `/ask` bằng đúng key đó, và họ tiêu tiền
> ngân sách LLM của mình mà mình không hề hay biết cho tới khi nhận hóa đơn
> hoặc thấy `cost_guard` báo hết ngân sách bất thường. Với thiết kế không có
> mặc định như hiện tại, app **crash ngay lúc khởi động** với lỗi
> `ValidationError` rõ ràng — mình biết ngay và sửa trước khi service từng
> nhận request nào, thay vì phát hiện ra sau khi đã bị khai thác.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật lấy được khi gọi `/ask`:
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T03:21:33.444861+00:00", "user_id": "sv-test", "tokens_in": 4, "tokens_out": 36, "cost_usd": 2.22e-05}
> ```
> Hai việc làm được mà `print("đã trả lời xong")` không làm được:
> 1. **Lọc/truy vấn theo trường** — vì log là JSON có cấu trúc, mình có thể
>    hỏi hệ thống log (Datadog, CloudWatch...) kiểu "tổng `cost_usd` của
>    `user_id=sv-test` trong 24h qua là bao nhiêu", hoặc "đếm số event
>    `ask_completed` mỗi giờ". Với `print` dạng chuỗi tự do thì phải viết
>    regex đoán mò, dễ vỡ khi đổi câu chữ.
> 2. **Đặt cảnh báo (alert) tự động** — ví dụ cảnh báo khi `cost_usd` trung
>    bình vượt ngưỡng, hoặc khi `level: "error"` xuất hiện quá N lần/phút.
>    Hệ thống giám sát đọc trực tiếp field `level`/`cost_usd` mà không cần
>    hiểu ngôn ngữ tự nhiên trong câu log.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1730 MB |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Bản 1-stage dùng `python:3.11` đầy đủ (không phải `-slim`) và giữ nguyên
> mọi thứ trong cùng một layer: base image full (~1GB, kèm compiler, header
> file, các gói hệ thống để build C extension), toàn bộ source code, và
> cache của `pip install`. Bản multi-stage của mình tách làm 2 stage: stage
> `builder` dùng `python:3.11-slim` để cài dependency bằng `pip install
> --user`, sau đó stage runtime (cũng `-slim`) chỉ `COPY --from=builder` đúng
> thư mục `.local` chứa package đã cài — không mang theo compiler, cache pip,
> hay bất kỳ file trung gian nào của quá trình build. Phần dung lượng chênh
> lệch chủ yếu là: (1) base image full so với slim, và (2) toàn bộ công cụ
> build (gcc, cache pip, apt lists...) chỉ tồn tại ở stage builder, không đi
> vào image cuối cùng.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> *Câu trả lời của bạn*

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: (1) code Python của mình có lỗ hổng (ví dụ một dependency
> cho phép remote code execution, hoặc một endpoint xử lý input không an
> toàn dẫn tới chạy được lệnh hệ thống); (2) kẻ tấn công khai thác lỗ hổng
> đó, process Python bắt đầu thực thi lệnh do họ điều khiển; (3) vì process
> đang chạy bằng **root bên trong container**, lệnh đó chạy với quyền root;
> (4) nếu container có cấu hình lỏng lẻo (mount volume host, chạy
> `--privileged`, hoặc lợi dụng lỗ hổng escape container khác), quyền root
> trong container có thể leo thang thành quyền cao trên chính máy host.
> Lệnh `USER app` trong Dockerfile của mình cắt đứt chuỗi này ở bước (3):
> process Python chạy bằng user thường `app`, không có quyền ghi vào hầu hết
> hệ thống file, không cài được package hệ thống, không đổi được cấu hình
> container. Kẻ tấn công dù chiếm được process cũng chỉ có quyền hạn chế của
> user đó — không tự động có quyền root để tiếp tục leo thang.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request trong 2 giây**. Cách đạt được: user gửi 10 request vào
> lúc `10:00:59` (giây cuối cùng của phút 10:00, bộ đếm của phút này chưa
> reset nên vẫn cho qua đủ 10 request), rồi ngay sau đó gửi tiếp 10 request
> vào lúc `10:01:01` (bộ đếm đã reset về 0 cho phút 10:01, nên lại cho qua
> đủ 10 request nữa). Tổng cộng 20 request lọt qua trong cửa sổ thời gian
> thực tế chỉ dài 2 giây, dù mỗi phút đều "đúng luật" 10/phút. Đây chính là
> lỗ hổng ở ranh giới phút mà sliding window (đếm 60 giây gần nhất tính từ
> thời điểm request, không neo theo đồng hồ) không mắc phải, vì nó luôn nhìn
> lại đúng 60 giây trước đó bất kể request đến vào giây nào.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit giới hạn **số lượng** request trong một cửa sổ thời gian, không
> quan tâm mỗi request tốn bao nhiêu tiền. Cost guard giới hạn **số tiền**
> đã tiêu trong tháng, không quan tâm tốc độ gửi request.
>
> - **Rate limit cho qua, cost guard phải chặn**: user gửi rất ít request
>   (ví dụ 2 request/phút, dưới hạn mức 10/phút nên rate limit luôn cho
>   qua), nhưng mỗi câu hỏi rất dài (nhiều token) hoặc user đã tích lũy chi
>   phí từ trước đó trong tháng khiến tổng vượt `monthly_budget_usd` — cost
>   guard phải chặn bằng 402 dù tần suất gọi hoàn toàn bình thường.
> - **Cost guard cho qua, rate limit phải chặn**: user còn dư ngân sách rất
>   nhiều (mới dùng hết 0.5$/10$ mỗi tháng), nhưng gửi 50 request dồn dập
>   trong 1 giây (ví dụ do bug ở client hoặc cố tình spam) — cost guard vẫn
>   thấy còn ngân sách nên cho qua, nhưng rate limit phải chặn bằng 429 vì
>   vượt `rate_limit_per_minute`, để bảo vệ hệ thống khỏi bị quá tải.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Thứ tự sự kiện: (1) Redis mất kết nối; (2) endpoint gộp (đóng vai trò cả
> liveness lẫn readiness) bắt đầu trả 503 ở cả 3 container, vì `store.ping()`
> thất bại; (3) orchestrator (Docker/Railway/K8s) coi 503 từ endpoint này là
> "liveness probe fail" chứ không chỉ "chưa sẵn sàng nhận traffic" — nó hiểu
> nhầm rằng chính process đang chết chứ không phải một dependency bên ngoài;
> (4) orchestrator restart cả 3 container gần như cùng lúc để "chữa" sự cố;
> (5) trong lúc cả 3 container đang khởi động lại, không còn container nào
> phục vụ được request — toàn bộ service down hoàn toàn, dù bản thân code
> Python của agent không hề có lỗi gì; (6) 30 giây sau Redis sống lại, nhưng
> nếu orchestrator có `restartPolicyMaxRetries` giới hạn, cụm có thể rơi vào
> trạng thái crash-loop trước khi ổn định trở lại. Đây chính là lý do
> `/health` (liveness) phải "nhẹ", không phụ thuộc Redis — chỉ `/ready`
> (readiness) mới được phép kiểm tra dependency, vì readiness fail chỉ khiến
> load balancer tạm ngừng đẩy traffic vào, không kích hoạt restart.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Với `store.py` hiện tại (lịch sử nằm trong Redis List, key `history:<user_id>`),
> dù `nginx`/load balancer đẩy mỗi request tới một trong 3 container `agent`
> khác nhau, `history_length` vẫn tăng dần đều đặn qua từng lần gọi (0, 1, 2,
> 3...) vì cả 3 container đọc/ghi chung một Redis — test
> `test_lich_su_duoc_dung_lai_giua_cac_request` (đã pass) chứng minh đúng
> hành vi này: request thứ hai thấy `history_length == 2` (user + assistant
> của lượt trước), bất kể request đó rơi vào instance nào.
>
> Nếu lịch sử được lưu trong một `dict` Python thay vì Redis, mỗi container
> sẽ có một dict riêng trong RAM của chính nó. Khi 3 request liên tiếp của
> cùng một `X-User-Id` bị load balancer phân phối luân phiên tới 3 container
> khác nhau, mỗi container chỉ thấy đúng những lượt hỏi mà chính nó xử lý —
> `history_length` sẽ nhảy lung tung kiểu 0, 0, 0 (mỗi container tưởng đây
> là lần đầu) thay vì tăng dần đều 0, 1, 2, thậm chí giảm về 0 nếu request
> tiếp theo rơi vào một container khác chưa từng thấy user này. Đây chính là
> hiện tượng "agent mất trí nhớ" mà bài toán stateless muốn tránh.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> lỗi ModuleNotFoundError: No module named 'uvicorn', nguyên nhân do pip install --user phụ thuộc $HOME không khớp khi chạy bằng non-root user, cách bạn (mình) tìm ra qua Deploy Logs trên Railway, và cách sửa bằng --prefix=/install copy vào /usr/local.
