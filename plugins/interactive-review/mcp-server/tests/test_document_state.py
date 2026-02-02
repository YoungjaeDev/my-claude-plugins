import pytest
from web_ui import DocumentState

def test_document_state_initialization():
    content = "line1\nline2\nline3"
    doc = DocumentState(content)
    assert doc.line_count == 3

def test_document_state_get_line():
    content = "first\nsecond\nthird"
    doc = DocumentState(content)
    assert doc.get_line(0) == "first"
    assert doc.get_line(1) == "second"
    assert doc.get_line(2) == "third"

def test_document_state_empty_lines():
    content = "line1\n\nline3"
    doc = DocumentState(content)
    assert doc.get_line(1) == ""

def test_document_state_unicode():
    content = "한글\n영어\n日本語"
    doc = DocumentState(content)
    assert doc.get_line(0) == "한글"
    assert doc.get_line(1) == "영어"
    assert doc.get_line(2) == "日本語"

def test_document_state_single_line():
    content = "single line without newline"
    doc = DocumentState(content)
    assert doc.line_count == 1
    assert doc.get_line(0) == "single line without newline"

def test_document_state_index_error():
    content = "line1\nline2"
    doc = DocumentState(content)
    with pytest.raises(IndexError):
        doc.get_line(5)
    with pytest.raises(IndexError):
        doc.get_line(-1)

def test_document_state_empty_content():
    content = ""
    doc = DocumentState(content)
    assert doc.line_count == 1  # empty string still has 1 "line"
    assert doc.get_line(0) == ""

def test_document_state_trailing_newline():
    content = "line1\nline2\n"
    doc = DocumentState(content)
    assert doc.line_count == 3
    assert doc.get_line(2) == ""
