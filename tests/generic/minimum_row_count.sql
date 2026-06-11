{% test minimum_row_count(model, min_rows) %}
Select count(*) as cnt 
from {{model}} having count(*) < {{min_rows}}
{% endtest %}