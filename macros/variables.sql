{% macro learn_variables() %}

    {% set your_name = "Joshua" %}
    {{ log("Hello " ~ your_name, info=True) }}

    {{ log( "hello " ~ var("user_name", "No username is set"), info = True)}}

{% endmacro %}