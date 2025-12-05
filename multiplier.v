module multiplier(
    input        clk,
    input        reset_n,
    input        op_start,
    input        op_clear,
    input  [31:0] multiplier,
    input  [31:0] multiplicand,
    output reg    op_done,
    output reg [63:0] result
);

    // 내부 상태 정의 
    localparam IDLE  = 2'b00;	//string of zeros
    localparam CALC  = 2'b01; // 덧셈/뺄셈 단계
    localparam SHIFT = 2'b10; // 시프트 단계
    localparam DONE  = 2'b11;	//string of ones

    reg [1:0] state;
    
    // Booth Multiplier Registers
    reg [63:0] p_reg; 
    reg [31:0] m_reg; // Multiplicand 저장
    reg        q_0;   // Booth bit (Q_(-1))
    reg [5:0]  count; // 32번 반복을 세기 위한 카운터 (0~31)

    // Sign extension wire for arithmetic operations
    wire [63:0] add_val;
    wire [63:0] sub_val;

    // 상위 32비트에만 더하거나 빼기 위해 위치를 맞춤
    assign add_val = {m_reg, 32'b0};
    assign sub_val = { (~m_reg + 1'b1), 32'b0}; // 2's complement for subtraction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state   <= IDLE;
            p_reg   <= 0;
            m_reg   <= 0;
            q_0     <= 0;
            count   <= 0;
            op_done <= 0;
            result  <= 0;
        end
        else if (op_clear) begin
            //op_clear 시 모든 내부 레지스터 및 출력 초기화 
            state   <= IDLE;
            p_reg   <= 0;
            m_reg   <= 0;
            q_0     <= 0;
            count   <= 0;
            op_done <= 0;
            result  <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    op_done <= 0;
                    if (op_start) begin
                        // 초기화 단계
                        m_reg <= multiplicand;
                        p_reg <= {32'b0, multiplier}; // 상위 32bit는 0, 하위 32bit는 승수
                        q_0   <= 0;
                        count <= 0;
                        state <= CALC; // 연산 시작
                    end
                end

                CALC: begin
                    // Booth Logic: 하위 비트(Q[0])와 q_0를 비교하여 연산 수행
                    case ({p_reg[0], q_0})
                        2'b01: p_reg <= p_reg + add_val; // Add Multiplicand to upper half
                        2'b10: p_reg <= p_reg + sub_val; // Sub Multiplicand from upper half
                        default: p_reg <= p_reg;         // No operation (00 or 11)
                    endcase
                    state <= SHIFT; // 다음 클럭에서 시프트 수행
                end

                SHIFT: begin
                    // Arithmetic Shift Right (ASR)
                    // 최상위 비트(부호)는 유지하면서 오른쪽으로 1비트 이동
                    // p_reg[0]는 q_0(다음 루프의 Q-1)로 이동
                    {p_reg, q_0} <= {p_reg[63], p_reg[63:1], p_reg[0]};
                    
                    // shift 연산 당 1 cycle 포함 [cite: 28]
                    if (count == 31) begin
                        state <= DONE;
                    end else begin
                        count <= count + 1;
                        state <= CALC; // 다시 연산 단계로
                    end
                end

                DONE: begin
                    // 연산 완료 시 result 출력 및 op_done = 1 [cite: 12]
                    result  <= p_reg;
                    op_done <= 1;
                    // op_clear가 들어오기 전까지 상태 유지 (else if op_clear가 처리함)
                end
            endcase
        end
    end

endmodule
