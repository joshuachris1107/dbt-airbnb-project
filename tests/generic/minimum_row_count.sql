{% test minimum_row_count(model, min_rows) %}
{ config( severity = 'warn') }
Select count(*) as cnt 
from {{model}} having count(*) < {{min_rows}}
{% endtest %}