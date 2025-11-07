# NAT 전용 EIP (enable_nat=false면 생성 안 함)
resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.prefix}-nat-eip"
  }
}
