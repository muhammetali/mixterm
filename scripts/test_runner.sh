#!/bin/bash
#
# MixTerm Merkezi Test Runner
# Bu script tüm test suite'lerini çalıştırır ve sonuçları raporlar.
# Contract-based testing prensibiyle, regresyonları önlemek için kullanılır.
#
# Kullanım:
#   ./scripts/test_runner.sh          # Tüm testleri çalıştır
#   ./scripts/test_runner.sh --quick  # Sadece birim testlerini çalıştır
#   ./scripts/test_runner.sh --widget # Sadece widget testlerini çalıştır
#   ./scripts/test_runner.sh --integration # Sadece entegrasyon testlerini çalıştır
#

set -e

# Renkli output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Proje root'una git
cd "$(dirname "$0")/.."

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   MixTerm Test Runner                     ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Test kategorileri
UNIT_TESTS=(
    "test/models/"
    "test/utils/"
    "test/services/"
)

WIDGET_TESTS=(
    "test/widgets/"
)

PROVIDER_TESTS=(
    "test/providers/"
)

INTEGRATION_TESTS=(
    "test/integration/"
)

# Fonksiyonlar
run_test_category() {
    local category_name=$1
    shift
    local test_paths=("$@")

    echo -e "${YELLOW}>>> $category_name${NC}"

    local all_passed=true
    local total_tests=0
    local passed_tests=0

    for path in "${test_paths[@]}"; do
        if [ -d "$path" ] || [ -f "$path" ]; then
            echo -e "  Running: ${path}"

            # Test çalıştır ve sonucu yakala
            set +e
            output=$(flutter test "$path" --reporter=compact 2>&1)
            exit_code=$?
            set -e

            # Sonucu parse et
            if [[ $output =~ ([0-9]+)\ tests?\ passed ]]; then
                passed_count="${BASH_REMATCH[1]}"
                ((passed_tests += passed_count))
                ((total_tests += passed_count))
            fi

            if [ $exit_code -eq 0 ]; then
                echo -e "    ${GREEN}PASSED${NC}"
            else
                echo -e "    ${RED}FAILED${NC}"
                echo "$output" | tail -20
                all_passed=false
            fi
        fi
    done

    if $all_passed; then
        echo -e "${GREEN}>>> $category_name: ALL PASSED ($passed_tests tests)${NC}"
    else
        echo -e "${RED}>>> $category_name: SOME TESTS FAILED${NC}"
    fi
    echo ""

    $all_passed
}

# Argüman işleme
MODE="${1:-all}"

case "$MODE" in
    --quick)
        echo -e "${YELLOW}Quick mode: Running unit tests only${NC}"
        echo ""
        run_test_category "Unit Tests" "${UNIT_TESTS[@]}"
        ;;
    --widget)
        echo -e "${YELLOW}Widget mode: Running widget tests only${NC}"
        echo ""
        run_test_category "Widget Tests" "${WIDGET_TESTS[@]}"
        ;;
    --provider)
        echo -e "${YELLOW}Provider mode: Running provider tests only${NC}"
        echo ""
        run_test_category "Provider Tests" "${PROVIDER_TESTS[@]}"
        ;;
    --integration)
        echo -e "${YELLOW}Integration mode: Running integration tests only${NC}"
        echo ""
        run_test_category "Integration Tests" "${INTEGRATION_TESTS[@]}"
        ;;
    all|*)
        echo -e "${YELLOW}Full mode: Running all test categories${NC}"
        echo ""

        # Önce flutter analyze çalıştır
        echo -e "${YELLOW}>>> Static Analysis${NC}"
        set +e
        flutter analyze
        analyze_exit=$?
        set -e

        if [ $analyze_exit -eq 0 ]; then
            echo -e "${GREEN}>>> Static Analysis: PASSED${NC}"
        else
            echo -e "${RED}>>> Static Analysis: WARNINGS/ERRORS FOUND${NC}"
        fi
        echo ""

        # Test kategorilerini çalıştır
        all_passed=true

        run_test_category "Unit Tests" "${UNIT_TESTS[@]}" || all_passed=false
        run_test_category "Provider Tests" "${PROVIDER_TESTS[@]}" || all_passed=false
        run_test_category "Widget Tests" "${WIDGET_TESTS[@]}" || all_passed=false
        run_test_category "Integration Tests" "${INTEGRATION_TESTS[@]}" || all_passed=false

        echo -e "${BLUE}============================================${NC}"
        if $all_passed; then
            echo -e "${GREEN}   ALL TESTS PASSED!                       ${NC}"
        else
            echo -e "${RED}   SOME TESTS FAILED                       ${NC}"
        fi
        echo -e "${BLUE}============================================${NC}"

        if ! $all_passed; then
            exit 1
        fi
        ;;
esac

echo ""
echo -e "${GREEN}Test run completed.${NC}"
